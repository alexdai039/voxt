import Foundation

enum ConfigurationTransferManager {
    struct MissingConfigurationIssue: Identifiable, Hashable {
        enum Scope: Hashable {
            case remoteASRProvider(RemoteASRProvider)
            case remoteLLMProvider(RemoteLLMProvider)
            case mlxModel(String)
            case whisperModel(String)
            case customLLMModel(String)
            case translationRemoteLLM(RemoteLLMProvider)
            case rewriteRemoteLLM(RemoteLLMProvider)
            case translationCustomLLM(String)
            case rewriteCustomLLM(String)
        }

        let scope: Scope
        let message: String

        var id: String {
            switch scope {
            case .remoteASRProvider(let provider):
                return "asr:\(provider.rawValue)"
            case .remoteLLMProvider(let provider):
                return "llm:\(provider.rawValue)"
            case .mlxModel(let repo):
                return "mlx:\(repo)"
            case .whisperModel(let modelID):
                return "whisper:\(modelID)"
            case .customLLMModel(let repo):
                return "custom:\(repo)"
            case .translationRemoteLLM(let provider):
                return "translation-llm:\(provider.rawValue)"
            case .rewriteRemoteLLM(let provider):
                return "rewrite-llm:\(provider.rawValue)"
            case .translationCustomLLM(let repo):
                return "translation-custom:\(repo)"
            case .rewriteCustomLLM(let repo):
                return "rewrite-custom:\(repo)"
            }
        }
    }

    static func missingConfigurationIssues(
        defaults: UserDefaults = .standard,
        mlxModelManager: MLXModelManager,
        whisperModelManager: WhisperKitModelManager,
        customLLMManager: CustomLLMModelManager
    ) -> [MissingConfigurationIssue] {
        var issues: [MissingConfigurationIssue] = []

        let featureSettings = FeatureSettingsStore.load(defaults: defaults)
        let remoteASR = RemoteModelConfigurationStore.loadConfigurations(
            from: defaults.string(forKey: AppPreferenceKey.remoteASRProviderConfigurations) ?? "",
            sensitiveValueLoading: .metadataOnly
        )
        let remoteLLM = RemoteModelConfigurationStore.loadConfigurations(
            from: defaults.string(forKey: AppPreferenceKey.remoteLLMProviderConfigurations) ?? "",
            sensitiveValueLoading: .metadataOnly
        )

        appendASRIssues(
            for: featureSettings.transcription.asrSelectionID,
            issues: &issues,
            remoteASR: remoteASR,
            mlxModelManager: mlxModelManager,
            whisperModelManager: whisperModelManager
        )
        if featureSettings.transcription.llmEnabled {
            appendTextModelIssues(
                for: featureSettings.transcription.llmSelectionID,
                issues: &issues,
                remoteLLM: remoteLLM,
                customLLMManager: customLLMManager
            )
        }

        appendASRIssues(
            for: featureSettings.translation.asrSelectionID,
            issues: &issues,
            remoteASR: remoteASR,
            mlxModelManager: mlxModelManager,
            whisperModelManager: whisperModelManager
        )
        appendTranslationModelIssues(
            for: featureSettings.translation,
            issues: &issues,
            remoteLLM: remoteLLM,
            customLLMManager: customLLMManager
        )

        appendASRIssues(
            for: featureSettings.rewrite.asrSelectionID,
            issues: &issues,
            remoteASR: remoteASR,
            mlxModelManager: mlxModelManager,
            whisperModelManager: whisperModelManager
        )
        appendTextModelIssues(
            for: featureSettings.rewrite.llmSelectionID,
            issues: &issues,
            remoteLLM: remoteLLM,
            customLLMManager: customLLMManager
        )

        return Array(Set(issues)).sorted { $0.id < $1.id }
    }
}
