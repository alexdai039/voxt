import SwiftUI

private func localized(_ key: String) -> String {
    AppLocalization.localizedString(key)
}

private func localizedKey(_ key: String) -> LocalizedStringKey {
    LocalizedStringKey(localized(key))
}

struct AboutSettingsView: View {
    let appUpdateManager: AppUpdateManager
    let navigationRequest: SettingsNavigationRequest?
    @AppStorage(AppPreferenceKey.betaUpdatesEnabled) private var betaUpdatesEnabled = false

    private var appVersionText: String {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        if let shortVersion, let buildVersion, !buildVersion.isEmpty {
            return "\(shortVersion) (\(buildVersion))"
        }
        if let shortVersion, !shortVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return shortVersion
        }
        if let buildVersion, !buildVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return buildVersion
        }
        return localized("Version metadata missing")
    }

    private let feedbackURL = URL(string: "https://github.com/hehehai/voxt/issues/new/choose")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(localizedKey("Version"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary.opacity(0.92))
                        Text(appVersionText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button(localized("Check for Updates")) {
                            appUpdateManager.checkForUpdatesWithUserInterface()
                    }
                    .disabled(appUpdateManager.shouldDisableInteractiveUpdateTrigger)
                    .buttonStyle(SettingsPillButtonStyle())
                }

                GeneralToggleRow(
                    title: localizedKey("Beta Updates"),
                    description: localizedKey("Check beta appcast updates when Voxt checks for app updates."),
                    isOn: $betaUpdatesEnabled
                )
                .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .settingsNavigationAnchor(.aboutVoxt)

            HStack(alignment: .top, spacing: 14) {
                AboutInfoCard(title: localizedKey("Project")) {
                    Link("github.com/hehehai/voxt", destination: URL(string: "https://github.com/hehehai/voxt")!)
                    Link(localized("Feedback"), destination: feedbackURL)
                }
                .settingsNavigationAnchor(.aboutProject)

                AboutInfoCard(title: localizedKey("Author")) {
                    Link("hehehai", destination: URL(string: "https://www.hehehai.cn/")!)
                }
                .settingsNavigationAnchor(.aboutAuthor)
            }
        }
        .onChange(of: betaUpdatesEnabled) { _, _ in
            appUpdateManager.betaUpdatesPreferenceDidChange()
        }
    }
}

private struct AboutInfoCard<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.92))

            VStack(alignment: .leading, spacing: 7) {
                content()
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: SettingsUIStyle.compactCornerRadius, style: .continuous)
                .fill(SettingsUIStyle.controlFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SettingsUIStyle.compactCornerRadius, style: .continuous)
                .strokeBorder(SettingsUIStyle.subtleBorderColor, lineWidth: 1)
        )
    }
}
