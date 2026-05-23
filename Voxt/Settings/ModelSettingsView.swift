import SwiftUI
import AppKit
import Combine

private func localized(_ key: String) -> String {
    AppLocalization.localizedString(key)
}

enum LocalASRConfigurationTarget: Equatable, Identifiable {
    case mlx(repo: String)
    case whisper(modelID: String)

    var id: String {
        switch self {
        case .mlx(let repo):
            return "mlx:\(repo)"
        case .whisper(let modelID):
            return "whisper:\(modelID)"
        }
    }
}

enum LocalModelRemovalTarget: Equatable, Identifiable {
    case mlx(repo: String)
    case whisper(modelID: String)
    case customLLM(repo: String)

    var id: String {
        switch self {
        case .mlx(let repo):
            return "mlx:\(MLXModelManager.canonicalModelRepo(repo))"
        case .whisper(let modelID):
            return "whisper:\(WhisperKitModelManager.canonicalModelID(modelID))"
        case .customLLM(let repo):
            return "custom-llm:\(CustomLLMModelManager.canonicalModelRepo(repo))"
        }
    }
}

struct ModelSettingsView: View {
    private struct DownloadEndpointCheckResult: Equatable {
        let isReachable: Bool
        let latencyText: String
        let throughputText: String
        let detailText: String
    }

    @AppStorage(AppPreferenceKey.transcriptionEngine) var engineRaw = TranscriptionEngine.mlxAudio.rawValue
    @AppStorage(AppPreferenceKey.enhancementMode) var enhancementModeRaw = EnhancementMode.off.rawValue
    @AppStorage(AppPreferenceKey.enhancementSystemPrompt) var systemPrompt = ""
    @AppStorage(AppPreferenceKey.translationSystemPrompt) var translationPrompt = ""
    @AppStorage(AppPreferenceKey.rewriteSystemPrompt) var rewritePrompt = ""
    @AppStorage(AppPreferenceKey.mlxModelRepo) var modelRepo = MLXModelManager.defaultModelRepo
    @AppStorage(AppPreferenceKey.whisperModelID) var whisperModelID = WhisperKitModelManager.defaultModelID
    @AppStorage(AppPreferenceKey.whisperTemperature) var whisperTemperature = 0.0
    @AppStorage(AppPreferenceKey.whisperVADEnabled) var whisperVADEnabled = true
    @AppStorage(AppPreferenceKey.whisperTimestampsEnabled) var whisperTimestampsEnabled = false
    @AppStorage(AppPreferenceKey.whisperRealtimeEnabled) var whisperRealtimeEnabled = false
    @AppStorage(AppPreferenceKey.localModelIdleUnloadDelaySeconds)
    var localModelIdleUnloadDelaySeconds = AppPreferenceKey.defaultLocalModelIdleUnloadDelaySeconds
    @AppStorage(AppPreferenceKey.whisperLocalASRTuningSettings) var whisperLocalASRTuningSettingsRaw = WhisperLocalTuningSettingsStore.defaultStoredValue()
    @AppStorage(AppPreferenceKey.customLLMModelRepo) var customLLMRepo = CustomLLMModelManager.defaultModelRepo
    @AppStorage(AppPreferenceKey.customLLMGenerationSettings) var customLLMGenerationSettingsRaw = CustomLLMGenerationSettingsStore.defaultStoredValue()
    @AppStorage(AppPreferenceKey.customLLMGenerationSettingsByRepo) var customLLMGenerationSettingsByRepoRaw = CustomLLMGenerationSettingsStore.defaultByRepoStoredValue()
    @AppStorage(AppPreferenceKey.translationCustomLLMModelRepo) var translationCustomLLMRepo = CustomLLMModelManager.defaultModelRepo
    @AppStorage(AppPreferenceKey.rewriteCustomLLMModelRepo) var rewriteCustomLLMRepo = CustomLLMModelManager.defaultModelRepo
    @AppStorage(AppPreferenceKey.translationModelProvider) var translationModelProviderRaw = TranslationModelProvider.customLLM.rawValue
    @AppStorage(AppPreferenceKey.translationFallbackModelProvider) var translationFallbackModelProviderRaw = TranslationModelProvider.customLLM.rawValue
    @AppStorage(AppPreferenceKey.rewriteModelProvider) var rewriteModelProviderRaw = RewriteModelProvider.customLLM.rawValue
    @AppStorage(AppPreferenceKey.translationTargetLanguage) var translationTargetLanguageRaw = TranslationTargetLanguage.english.rawValue
    @AppStorage(AppPreferenceKey.remoteASRSelectedProvider) var remoteASRSelectedProviderRaw = RemoteASRProvider.openAIWhisper.rawValue
    @AppStorage(AppPreferenceKey.remoteASRProviderConfigurations) var remoteASRProviderConfigurationsRaw = ""
    @AppStorage(AppPreferenceKey.asrHintSettings) var asrHintSettingsRaw = ASRHintSettingsStore.defaultStoredValue()
    @AppStorage(AppPreferenceKey.mlxLocalASRTuningSettings) var mlxLocalASRTuningSettingsRaw = "{}"
    @AppStorage(AppPreferenceKey.userMainLanguageCodes) var userMainLanguageCodesRaw = UserMainLanguageOption.defaultStoredSelectionValue
    @AppStorage(AppPreferenceKey.remoteLLMSelectedProvider) var remoteLLMSelectedProviderRaw = RemoteLLMProvider.openAI.rawValue
    @AppStorage(AppPreferenceKey.remoteLLMProviderConfigurations) var remoteLLMProviderConfigurationsRaw = ""
    @AppStorage(AppPreferenceKey.translationRemoteLLMProvider) var translationRemoteLLMProviderRaw = ""
    @AppStorage(AppPreferenceKey.rewriteRemoteLLMProvider) var rewriteRemoteLLMProviderRaw = ""
    @AppStorage(AppPreferenceKey.useHfMirror) var useHfMirror = false
    @AppStorage(AppPreferenceKey.modelStorageRootPath) var modelStorageRootPath = ""
    @AppStorage(AppPreferenceKey.interfaceLanguage) var interfaceLanguageRaw = AppInterfaceLanguage.system.rawValue
    @AppStorage(AppPreferenceKey.featureSettings) var featureSettingsRaw = ""

    let mlxModelManager: MLXModelManager
    let whisperModelManager: WhisperKitModelManager
    let customLLMManager: CustomLLMModelManager
    @ObservedObject var mainWindowState: MainWindowVisibilityState
    let missingConfigurationIssues: [ConfigurationTransferManager.MissingConfigurationIssue]
    let navigationRequest: SettingsNavigationRequest?
    let isActive: Bool

    @State var catalogTab: ModelCatalogTab = .asr
    @State var selectedTags = Set<String>()
    @State var cachedFeatureSettings = FeatureSettingsStore.load()
    @State var cachedRemoteASRConfigurations = [String: RemoteProviderConfiguration]()
    @State var cachedRemoteLLMConfigurations = [String: RemoteProviderConfiguration]()
    @State private var modelStorageDisplayPath = ""
    @State private var modelStorageSelectionError: String?
    @State var showMirrorInfo = false
    @State private var showIdleUnloadDelayInfo = false
    @State var editingASRProvider: RemoteASRProvider?
    @State var editingLLMProvider: RemoteLLMProvider?
    @State private var activeASRHintTarget: ASRHintTarget?
    @State var activeLocalASRConfigurationTarget: LocalASRConfigurationTarget?
    @State var isCustomLLMConfigurationPresented = false
    @State var customLLMConfigurationRepo: String?
    @State private var isModelDownloadSettingsPresented = false
    @State private var isTestingGlobalDownloadEndpoint = false
    @State private var isTestingChinaDownloadEndpoint = false
    @State private var expandedModelGroupIDs = Set<String>()
    @State private var collapsedModelGroupIDs = Set<String>()
    @State private var globalDownloadEndpointResult: DownloadEndpointCheckResult?
    @State private var chinaDownloadEndpointResult: DownloadEndpointCheckResult?
    @State var catalogSnapshot = ModelSettingsCatalogSnapshot.empty
    @State private var isCatalogRefreshScheduled = false
    @State private var isRefreshingCatalogSnapshot = false
    @State private var needsAnotherCatalogRefresh = false
    @State var lastHandledDownloadLifecycleToken: ModelSettingsDownloadLifecycleToken?
    @State var pendingModelRemovalTarget: LocalModelRemovalTarget?
    @State var uninstallingModelTarget: LocalModelRemovalTarget?
    @State var cancellingInstallTargets = Set<LocalModelInstallTarget>()

    let modelStateRefreshTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var selectedEngine: TranscriptionEngine {
        TranscriptionEngine(rawValue: engineRaw) ?? .mlxAudio
    }

    var selectedEnhancementMode: EnhancementMode {
        EnhancementMode.resolved(
            storedRawValue: enhancementModeRaw,
            appleIntelligenceAvailable: appleIntelligenceAvailable,
            customLLMAvailable: customEnhancementModelAvailable,
            remoteLLMAvailable: remoteEnhancementModelAvailable
        )
    }

    var selectedRemoteASRProvider: RemoteASRProvider {
        RemoteASRProvider(rawValue: remoteASRSelectedProviderRaw) ?? .openAIWhisper
    }

    var selectedRemoteLLMProvider: RemoteLLMProvider {
        RemoteLLMProvider(rawValue: remoteLLMSelectedProviderRaw) ?? .openAI
    }

    var selectedTranslationModelProvider: TranslationModelProvider {
        TranslationModelProvider(rawValue: translationModelProviderRaw) ?? .customLLM
    }

    var selectedRewriteModelProvider: RewriteModelProvider {
        RewriteModelProvider(rawValue: rewriteModelProviderRaw) ?? .customLLM
    }

    var selectedTranslationFallbackModelProvider: TranslationModelProvider {
        TranslationProviderResolver.sanitizedFallbackProvider(
            TranslationModelProvider(rawValue: translationFallbackModelProviderRaw) ?? .customLLM
        )
    }

    var selectedTranslationTargetLanguage: TranslationTargetLanguage {
        TranslationTargetLanguage(rawValue: translationTargetLanguageRaw) ?? .english
    }

    var remoteASRConfigurations: [String: RemoteProviderConfiguration] {
        cachedRemoteASRConfigurations
    }

    var remoteLLMConfigurations: [String: RemoteProviderConfiguration] {
        cachedRemoteLLMConfigurations
    }

    var selectedUserLanguageCodes: [String] {
        UserMainLanguageOption.storedSelection(from: userMainLanguageCodesRaw)
    }

    var appleIntelligenceAvailable: Bool {
        if #available(macOS 26.0, *) {
            return TextEnhancer.isAvailable
        }
        return false
    }

    var customEnhancementModelAvailable: Bool {
        customLLMManager.isModelDownloaded(repo: customLLMManager.currentModelRepo)
    }

    var remoteEnhancementModelAvailable: Bool {
        RemoteModelConfigurationStore.isStoredLLMConfigurationConfigured(
            provider: selectedRemoteLLMProvider,
            stored: remoteLLMConfigurations
        )
    }

    private var featureSettings: FeatureSettings {
        cachedFeatureSettings
    }

    private var catalogBuilder: ModelCatalogBuilder {
        ModelCatalogBuilder(
            mlxModelManager: mlxModelManager,
            whisperModelManager: whisperModelManager,
            customLLMManager: customLLMManager,
            remoteASRConfigurations: remoteASRConfigurations,
            remoteLLMConfigurations: remoteLLMConfigurations,
            featureSettings: featureSettings,
            hasIssue: hasIssue(for:),
            customLLMBadgeText: customLLMBadgeText(for:),
            remoteASRStatusText: { provider, configuration in
                remoteASRStatusText(for: provider, configuration: configuration)
            },
            remoteLLMBadgeText: remoteLLMBadgeText(for:),
            primaryUserLanguageCode: selectedUserLanguageCodes.first,
            mlxInstallSnapshot: mlxInstallSnapshot(for:),
            whisperInstallSnapshot: whisperInstallSnapshot(for:),
            customLLMInstallSnapshot: customLLMInstallSnapshot(for:),
            catalogPrimaryAction: {
                ModelSettingsInstallActionResolver.catalogPrimaryAction(
                    for: $0,
                    perform: performInstallAction(_:kind:)
                )
            },
            catalogSecondaryActions: {
                ModelSettingsInstallActionResolver.catalogSecondaryActions(
                    for: $0,
                    perform: performInstallAction(_:kind:)
                )
            },
            configureASRProvider: { editingASRProvider = $0 },
            configureLLMProvider: { editingLLMProvider = $0 },
            showASRHintTarget: { activeASRHintTarget = $0 }
        )
    }

    private var allEntries: [ModelCatalogEntry] { catalogSnapshot.allEntries }

    private var availableTags: [String] { catalogSnapshot.availableTags }

    private var availableTagGroups: [[String]] { catalogSnapshot.availableTagGroups }

    private var filteredEntries: [ModelCatalogEntry] { catalogSnapshot.filteredEntries }

    private var displayItems: [ModelCatalogDisplayItem] { catalogSnapshot.displayItems }

    private var tagFilterBar: some View {
        Group {
            if !availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(availableTagGroups.enumerated()), id: \.offset) { index, group in
                            HStack(spacing: 8) {
                                ForEach(group, id: \.self) { tag in
                                    ModelTagChip(
                                        title: tag,
                                        isSelected: selectedTags.contains(tag),
                                        action: { toggleTag(tag) }
                                    )
                                }
                            }

                            if index < availableTagGroups.count - 1 {
                                Rectangle()
                                    .fill(SettingsUIStyle.subtleBorderColor.opacity(0.95))
                                    .frame(width: 1, height: 20)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var modelCatalogContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredEntries.isEmpty {
                    ModelEmptyStateView()
                } else {
                    ForEach(displayItems) { item in
                        modelCatalogItemView(item)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func modelCatalogItemView(_ item: ModelCatalogDisplayItem) -> some View {
        switch item {
        case .row(let entry):
            ModelCatalogRow(entry: entry)
        case .group(let group):
            ModelCatalogGroupCard(
                group: group,
                isExpanded: isModelGroupExpanded(group),
                onToggle: { toggleModelGroup(group) }
            )
        }
    }

    private func isModelGroupExpanded(_ group: ModelCatalogGroupSection) -> Bool {
        if expandedModelGroupIDs.contains(group.id) {
            return true
        }
        if collapsedModelGroupIDs.contains(group.id) {
            return false
        }
        return group.defaultExpanded
    }

    private func toggleModelGroup(_ group: ModelCatalogGroupSection) {
        let isExpanded = isModelGroupExpanded(group)
        if group.defaultExpanded {
            if isExpanded {
                collapsedModelGroupIDs.insert(group.id)
            } else {
                collapsedModelGroupIDs.remove(group.id)
            }
            expandedModelGroupIDs.remove(group.id)
            return
        }

        if isExpanded {
            expandedModelGroupIDs.remove(group.id)
        } else {
            expandedModelGroupIDs.insert(group.id)
        }
        collapsedModelGroupIDs.remove(group.id)
    }

    var mainContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            modelTabHeader
            tagFilterBar
            modelCatalogContent
        }
    }

    private var contentWithSheets: some View {
        contentWithLifecycle
        .sheet(item: $editingASRProvider) { provider in
            RemoteProviderConfigurationSheet(
                providerTitle: provider.title,
                credentialHint: asrCredentialHint(for: provider),
                showsDoubaoFields: provider == .doubaoASR,
                testTarget: .asr(provider),
                configuration: RemoteModelConfigurationStore.resolvedASRConfiguration(
                    provider: provider,
                    stored: RemoteModelConfigurationStore.loadConfigurations(from: remoteASRProviderConfigurationsRaw)
                )
            ) { updated in
                saveRemoteASRConfiguration(updated)
            }
        }
        .sheet(item: $editingLLMProvider) { provider in
            RemoteProviderConfigurationSheet(
                providerTitle: provider.title,
                credentialHint: nil,
                showsDoubaoFields: false,
                testTarget: .llm(provider),
                configuration: RemoteModelConfigurationStore.resolvedLLMConfiguration(
                    provider: provider,
                    stored: RemoteModelConfigurationStore.loadConfigurations(from: remoteLLMProviderConfigurationsRaw)
                )
            ) { updated in
                saveRemoteLLMConfiguration(updated)
            }
        }
        .sheet(item: $activeASRHintTarget) { target in
            ASRHintSettingsSheet(
                target: target,
                userLanguageCodes: selectedUserLanguageCodes,
                mlxModelRepo: target == .mlxAudio ? modelRepo : nil,
                initialSettings: resolvedASRHintSettings(for: target)
            ) { updated in
                saveASRHintSettings(updated, for: target)
            }
        }
        .sheet(item: $activeLocalASRConfigurationTarget) { target in
            localASRConfigurationSheet(for: target)
        }
        .sheet(isPresented: $isCustomLLMConfigurationPresented) {
            let repo = customLLMConfigurationRepo ?? customLLMRepo
            CustomLLMGenerationSettingsSheet(
                modelTitle: customLLMManager.displayTitle(for: repo),
                settings: customLLMGenerationSettingsBinding(for: repo)
            ) {
                isCustomLLMConfigurationPresented = false
                customLLMConfigurationRepo = nil
            }
        }
        .sheet(isPresented: $isModelDownloadSettingsPresented) {
            modelDownloadSettingsSheet
        }
        .alert(item: $pendingModelRemovalTarget) { target in
            Alert(
                title: Text(AppLocalization.localizedString("Uninstall Model?")),
                message: Text(uninstallConfirmationMessage(for: target)),
                primaryButton: .destructive(Text(AppLocalization.localizedString("Uninstall"))) {
                    confirmDeleteModel(target)
                },
                secondaryButton: .cancel()
            )
        }
    }

    var body: some View {
        contentWithSheets
        .id(interfaceLanguageRaw)
    }

    func reloadCachedConfigurationState() {
        cachedFeatureSettings = FeatureSettingsStore.load(defaults: .standard)
        cachedRemoteASRConfigurations = RemoteModelConfigurationStore.loadConfigurations(
            from: remoteASRProviderConfigurationsRaw,
            sensitiveValueLoading: .metadataOnly
        )
        cachedRemoteLLMConfigurations = RemoteModelConfigurationStore.loadConfigurations(
            from: remoteLLMProviderConfigurationsRaw,
            sensitiveValueLoading: .metadataOnly
        )
        refreshCatalogSnapshot()
    }

    func refreshCatalogSnapshot() {
        if isRefreshingCatalogSnapshot {
            needsAnotherCatalogRefresh = true
            return
        }
        guard !isCatalogRefreshScheduled else { return }
        isCatalogRefreshScheduled = true
        DispatchQueue.main.async {
            isCatalogRefreshScheduled = false
            rebuildCatalogSnapshot()
        }
    }

    private func rebuildCatalogSnapshot() {
        if isRefreshingCatalogSnapshot {
            needsAnotherCatalogRefresh = true
            return
        }
        isRefreshingCatalogSnapshot = true
        defer {
            isRefreshingCatalogSnapshot = false
            if needsAnotherCatalogRefresh {
                needsAnotherCatalogRefresh = false
                refreshCatalogSnapshot()
            }
        }

        reconcileCancellingInstallTargets()

        let entries = switch catalogTab {
        case .asr:
            catalogBuilder.asrEntries()
        case .llm:
            catalogBuilder.llmEntries()
        }

        catalogSnapshot = ModelSettingsCatalogSnapshotBuilder.build(
            entries: entries,
            selectedTags: selectedTags
        )
    }

    private func chooseModelStorageDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = ModelStorageDirectoryManager.resolvedRootURL()
        panel.prompt = localized("Choose")

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        let currentURL = ModelStorageDirectoryManager.resolvedRootURL().standardizedFileURL
        let proposedURL = selectedURL.standardizedFileURL
        guard proposedURL != currentURL else { return }

        let alert = NSAlert()
        alert.messageText = localized("Change Model Storage Path?")
        alert.informativeText = localized("After changing the model storage path, previously downloaded local models will need to be downloaded again.")
        alert.addButton(withTitle: localized("Confirm"))
        alert.addButton(withTitle: localized("Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try ModelStorageDirectoryManager.saveUserSelectedRootURL(selectedURL)
            modelStorageSelectionError = nil
            refreshAllModelStorageRoots()
            refreshModelStorageDisplayPath()
            refreshCatalogSnapshot()
        } catch {
            modelStorageSelectionError = AppLocalization.format(
                "Failed to update model storage path: %@",
                error.localizedDescription
            )
        }
    }

    func refreshModelStorageDisplayPath() {
        let resolved = ModelStorageDirectoryManager.resolvedRootURL().path
        modelStorageDisplayPath = resolved
    }

    private func openModelStorageInFinder() {
        Task { @MainActor in
            ModelStorageDirectoryManager.openRootInFinder()
        }
    }

    private func testGlobalDownloadEndpoint() {
        Task {
            await runDownloadEndpointCheck(
                using: MLXModelManager.defaultHubBaseURL,
                isTesting: { isTestingGlobalDownloadEndpoint = $0 },
                setResult: { globalDownloadEndpointResult = $0 }
            )
        }
    }

    private func testChinaDownloadEndpoint() {
        Task {
            await runDownloadEndpointCheck(
                using: MLXModelManager.mirrorHubBaseURL,
                isTesting: { isTestingChinaDownloadEndpoint = $0 },
                setResult: { chinaDownloadEndpointResult = $0 }
            )
        }
    }

    private func runDownloadEndpointCheck(
        using baseURL: URL,
        isTesting: @escaping (Bool) -> Void,
        setResult: @escaping (DownloadEndpointCheckResult) -> Void
    ) async {
        await MainActor.run { isTesting(true) }
        let result = await measureDownloadEndpoint(baseURL: baseURL)
        await MainActor.run {
            setResult(result)
            isTesting(false)
        }
    }

    private func measureDownloadEndpoint(baseURL: URL) async -> DownloadEndpointCheckResult {
        let targetURL = baseURL.appending(path: "robots.txt")
        var request = URLRequest(url: targetURL)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let startedAt = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsed = max(Date().timeIntervalSince(startedAt), 0.001)
            let bytesPerSecond = Double(data.count) / elapsed

            let latencyText = AppLocalization.format("Latency: %@", String(format: "%.0f ms", elapsed * 1000))
            let throughputText = AppLocalization.format(
                "Speed: %@/s",
                ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file)
            )

            if let httpResponse = response as? HTTPURLResponse, !(200..<400).contains(httpResponse.statusCode) {
                return DownloadEndpointCheckResult(
                    isReachable: false,
                    latencyText: latencyText,
                    throughputText: throughputText,
                    detailText: AppLocalization.format("Request failed (HTTP %@).", String(httpResponse.statusCode))
                )
            }

            return DownloadEndpointCheckResult(
                isReachable: true,
                latencyText: latencyText,
                throughputText: throughputText,
                detailText: AppLocalization.format("Downloaded %@ to verify connectivity.", ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))
            )
        } catch {
            return DownloadEndpointCheckResult(
                isReachable: false,
                latencyText: localized("Latency: --"),
                throughputText: localized("Speed: --"),
                detailText: AppLocalization.format("Connection failed: %@", error.localizedDescription)
            )
        }
    }

    private var modelTabHeader: some View {
        HStack(spacing: 10) {
            ModelCatalogTabPicker(selectedTab: $catalogTab)

            Spacer(minLength: 0)

            if !missingConfigurationIssues.isEmpty {
                Menu {
                    ForEach(missingConfigurationIssueDescriptions, id: \.self) { description in
                        Text(description)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(
                            missingConfigurationIssues.count == 1
                            ? localized("1 model needs setup")
                            : AppLocalization.format("%d models need setup", missingConfigurationIssues.count)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.orange.opacity(0.10))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .help(missingConfigurationIssueDescriptions.joined(separator: "\n"))
            }

            Text(AppLocalization.format("%d items", filteredEntries.count))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                isModelDownloadSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(SettingsCompactIconButtonStyle(size: 32))

            Button(action: openModelDebugWindow) {
                Text(localized("Debug"))
            }
            .buttonStyle(SettingsPillButtonStyle(horizontalPadding: 12))
        }
    }

    private var modelDownloadSettingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("Model Download Settings"))
                .font(.title3.weight(.semibold))

            GeneralSettingsCard(titleText: localized("Model Storage")) {
                GeneralFieldRow(title: LocalizedStringKey(localized("Storage Path"))) {
                    Button(action: openModelStorageInFinder) {
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .font(.caption)
                            Text(modelStorageDisplayPath.isEmpty ? ModelStorageDirectoryManager.defaultRootURL.path : modelStorageDisplayPath)
                                .underline()
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                        }
                        .frame(width: 260, alignment: .leading)
                    }
                    .buttonStyle(SettingsInlineSelectorButtonStyle())
                    .help(localized("Open folder"))

                    Button(localized("Choose")) {
                        chooseModelStorageDirectory()
                    }
                    .buttonStyle(SettingsPillButtonStyle())
                }

                if let modelStorageSelectionError, !modelStorageSelectionError.isEmpty {
                    Text(modelStorageSelectionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            GeneralSettingsCard(titleText: localized("Memory")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text(localized("Unload Delay"))
                            .foregroundStyle(.secondary)

                        Button {
                            showIdleUnloadDelayInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showIdleUnloadDelayInfo, arrowEdge: .top) {
                            Text(localized("Idle unload delay for local ASR and local LLM models. Lower values reduce memory usage; higher values favor faster reuse."))
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(width: 280, alignment: .leading)
                        }

                        Spacer(minLength: 0)
                    }

                    LocalModelIdleUnloadDelayControl(
                        value: $localModelIdleUnloadDelaySeconds,
                        range: AppPreferenceKey.localModelIdleUnloadDelayMinimumSeconds...AppPreferenceKey.localModelIdleUnloadDelayMaximumSeconds
                    )
                }
            }

            GeneralSectionDivider()

            VStack(alignment: .leading, spacing: 16) {
                GeneralToggleRow(
                    title: LocalizedStringKey(localized("Use China mirror")),
                    description: LocalizedStringKey(localized("Use the mirror for Hugging Face model downloads.")),
                    isOn: $useHfMirror
                )

                endpointTestRow(
                    title: localized("Global"),
                    subtitle: "https://huggingface.co",
                    isTesting: isTestingGlobalDownloadEndpoint,
                    result: globalDownloadEndpointResult,
                    actionTitle: localized("Test"),
                    action: testGlobalDownloadEndpoint
                )

                endpointTestRow(
                    title: localized("China Mirror"),
                    subtitle: "https://hf-mirror.com",
                    isTesting: isTestingChinaDownloadEndpoint,
                    result: chinaDownloadEndpointResult,
                    actionTitle: localized("Test"),
                    action: testChinaDownloadEndpoint
                )
            }

            SettingsDialogActionRow {
                Button(localized("Done")) {
                    isModelDownloadSettingsPresented = false
                }
                .buttonStyle(SettingsPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .settingsDialogChrome(width: 560, onClose: {
            isModelDownloadSettingsPresented = false
        })
    }

    @ViewBuilder
    private func endpointTestRow(
        title: String,
        subtitle: String,
        isTesting: Bool,
        result: DownloadEndpointCheckResult?,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                }

                if let result {
                    OnboardingPermissionStatusBadge(isGranted: result.isReachable)
                }

                Button(actionTitle, action: action)
                    .buttonStyle(SettingsPillButtonStyle())
                    .disabled(isTesting)
            }

            if let result {
                Text("\(result.latencyText) · \(result.throughputText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.detailText)
                    .font(.caption)
                    .foregroundStyle(
                        result.isReachable
                        ? AnyShapeStyle(.secondary)
                        : AnyShapeStyle(Color.orange)
                    )
            }
        }
    }

    var shouldPollModelState: Bool {
        ModelSettingsProgressRefreshSupport.shouldPollModelState(
            mlxState: mlxModelManager.state,
            mlxHasActiveDownloadingRepos: mlxModelManager.activeDownloadRepos.contains { repo in
                if case .downloading = mlxModelManager.state(for: repo) {
                    return true
                }
                return false
            },
            whisperState: whisperModelManager.state,
            whisperActiveDownload: whisperModelManager.activeDownload,
            customLLMState: customLLMManager.state
        )
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            if ModelCatalogTag.exclusiveSelectionTags.contains(tag) {
                selectedTags.subtract(ModelCatalogTag.exclusiveSelectionTags)
            }
            selectedTags.insert(tag)
        }
    }

    func pruneSelectedTags() {
        selectedTags = selectedTags.intersection(Set(availableTags))
    }

    private func openModelDebugWindow() {
        guard let appDelegate = AppDelegate.shared else { return }
        switch catalogTab {
        case .asr:
            ASRDebugWindowManager.shared.present(appDelegate: appDelegate)
        case .llm:
            LLMDebugWindowManager.shared.present(appDelegate: appDelegate)
        }
    }

    private var missingConfigurationIssueDescriptions: [String] {
        missingConfigurationIssues.map(missingConfigurationIssueDescription(for:))
    }

    private func missingConfigurationIssueDescription(
        for issue: ConfigurationTransferManager.MissingConfigurationIssue
    ) -> String {
        switch issue.scope {
        case .remoteASRProvider(let provider):
            return AppLocalization.format("%@ %@: %@", provider.title, localized("ASR"), issue.message)
        case .remoteLLMProvider(let provider):
            return AppLocalization.format("%@ %@: %@", provider.title, localized("LLM"), issue.message)
        case .mlxModel(let repo):
            return AppLocalization.format("%@ %@: %@", mlxModelManager.displayTitle(for: repo), localized("ASR"), issue.message)
        case .whisperModel(let modelID):
            return AppLocalization.format("%@ %@: %@", whisperModelManager.displayTitle(for: modelID), localized("Whisper"), issue.message)
        case .customLLMModel(let repo):
            return AppLocalization.format("%@ %@: %@", customLLMManager.displayTitle(for: repo), localized("LLM"), issue.message)
        case .translationRemoteLLM(let provider):
            return AppLocalization.format("%@ %@: %@", provider.title, localized("Translation"), issue.message)
        case .rewriteRemoteLLM(let provider):
            return AppLocalization.format("%@ %@: %@", provider.title, localized("Rewrite"), issue.message)
        case .translationCustomLLM(let repo):
            return AppLocalization.format("%@ %@: %@", customLLMManager.displayTitle(for: repo), localized("Translation"), issue.message)
        case .rewriteCustomLLM(let repo):
            return AppLocalization.format("%@ %@: %@", customLLMManager.displayTitle(for: repo), localized("Rewrite"), issue.message)
        }
    }
}

private struct LocalModelIdleUnloadDelayControl: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            LocalModelIdleUnloadDelaySlider(
                value: $value,
                range: range
            )
            .frame(maxWidth: .infinity)
            .frame(height: 38)

            HStack(alignment: .firstTextBaseline) {
                Text(formatIdleUnloadDelay(range.lowerBound))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatIdleUnloadDelay(range.upperBound))
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
            .monospacedDigit()
        }
    }
}

private struct LocalModelIdleUnloadDelaySlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let progress = normalizedProgress
            let thumbX = max(0, min(geometry.size.width, geometry.size.width * progress))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(SettingsUIStyle.subtleFillColor)

                tickMarks
                    .padding(.horizontal, 18)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(isActive ? 0.10 : 0.08))
                    .frame(width: max(20, thumbX - 12), height: 30)
                    .offset(x: 4)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(activeTint.opacity(isActive ? 0.92 : 0.60))
                    .frame(width: 8, height: 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(activeTint.opacity(isActive ? 0.22 : 0.12), lineWidth: 1)
                    )
                    .offset(x: min(max(0, thumbX - 4), max(0, geometry.size.width - 8)))

                HStack {
                    Spacer()
                    Text(formatIdleUnloadDelay(value))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                        .padding(.trailing, 12)
                }
            }
            .frame(height: 38)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.accentColor.opacity(0.45) : SettingsUIStyle.subtleBorderColor,
                        lineWidth: 1
                    )
            )
            .shadow(color: isActive ? Color.accentColor.opacity(0.10) : .clear, radius: 6, y: 1)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        updateValue(at: gesture.location.x, width: geometry.size.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { isHovering = $0 }
        }
    }

    private var isActive: Bool {
        isHovering || isDragging
    }

    private var activeTint: Color {
        isActive ? Color.accentColor : Color.primary
    }

    private var normalizedProgress: CGFloat {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let span = max(range.upperBound - range.lowerBound, 1)
        return CGFloat(clamped - range.lowerBound) / CGFloat(span)
    }

    @ViewBuilder
    private var tickMarks: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { index in
                    Circle()
                        .fill(Color.primary.opacity(index == 0 ? 0.18 : 0.14))
                        .frame(width: 4.5, height: 4.5)
                        .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : index == 8 ? .trailing : .center)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
    }

    private func updateValue(at locationX: CGFloat, width: CGFloat) {
        let resolvedWidth = max(width, 1)
        let clampedX = min(max(locationX, 0), resolvedWidth)
        let progress = clampedX / resolvedWidth
        let resolved = range.lowerBound + Int(round(progress * CGFloat(range.upperBound - range.lowerBound)))
        value = min(max(resolved, range.lowerBound), range.upperBound)
    }
}

private func formatIdleUnloadDelay(_ seconds: Int) -> String {
    guard seconds >= 60 else {
        return AppLocalization.format("%@s", String(seconds))
    }

    let minutes = Double(seconds) / 60.0
    let hasFraction = seconds % 60 != 0
    let formattedMinutes = minutes.formatted(
        .number.precision(.fractionLength(hasFraction && minutes < 10 ? 1 : 0))
    )
    return AppLocalization.format("%@min", formattedMinutes)
}
