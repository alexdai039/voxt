import SwiftUI

extension FeatureSettingsView {
    var translationContent: some View {
        featurePage(
            title: "",
            subtitle: "",
            icon: "",
            pills: translationPills
        ) {
            FeatureSettingsCard(title: featureSettingsLocalized("Translation Flow")) {
                FeatureSelectorRow(
                    title: featureSettingsLocalized("Audio Model"),
                    value: asrSelectionSummary(featureSettings.translation.asrSelectionID),
                    action: { selectorSheet = .translationASR }
                )

                FeatureSelectorRow(
                    title: featureSettingsLocalized("Translation Model"),
                    value: translationSelectionSummary(featureSettings.translation.modelSelectionID),
                    action: { selectorSheet = .translationModel }
                )

                HStack(alignment: .center, spacing: 18) {
                    Text(featureSettingsLocalized("Target Language"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.92))
                    Spacer(minLength: 0)
                    SettingsMenuPicker(
                        selection: binding(
                            get: { featureSettings.translation.targetLanguage },
                            set: { featureSettings.translation.targetLanguageRawValue = $0.rawValue }
                        ),
                        options: TranslationTargetLanguage.allCases.map {
                            SettingsMenuOption(value: $0, title: $0.title)
                        },
                        selectedTitle: featureSettings.translation.targetLanguage.title,
                        width: 280
                    )
                }

                FeatureToggleRow(
                    title: featureSettingsLocalized("Selected Translation Result Editor"),
                    detail: "",
                    isOn: binding(
                        get: { featureSettings.translation.showResultWindow },
                        set: { featureSettings.translation.showResultWindow = $0 }
                    )
                )

                if featureSettings.translation.modelSelectionID.translationSelection != .whisperDirectTranslate {
                    FeaturePromptSection(
                        title: featureSettingsLocalized("Translation Prompt"),
                        text: promptBinding(
                            get: { featureSettings.translation.prompt },
                            set: { featureSettings.translation.prompt = $0 },
                            kind: .translation
                        ),
                        defaultText: AppPromptDefaults.text(for: .translation),
                        variables: ModelSettingsPromptVariables.translation,
                        guidance: "",
                        persistChanges: saveFeatureSettings
                    )
                } else {
                    FeatureHintBanner(
                        title: featureSettingsLocalized("Whisper Direct Translation"),
                        detail: featureSettingsLocalized("Prompt editing is hidden here because Whisper direct translation does not consume a text prompt.")
                    )
                }
            }
        }
    }

    var rewriteContent: some View {
        featurePage(
            title: "",
            subtitle: "",
            icon: "",
            pills: rewritePills
        ) {
            FeatureSettingsCard(title: featureSettingsLocalized("Rewrite Flow")) {
                FeatureSelectorRow(
                    title: featureSettingsLocalized("Audio Model"),
                    value: asrSelectionSummary(featureSettings.rewrite.asrSelectionID),
                    action: { selectorSheet = .rewriteASR }
                )

                FeatureSelectorRow(
                    title: featureSettingsLocalized("Enhancement Model"),
                    value: llmSelectionSummary(featureSettings.rewrite.llmSelectionID),
                    action: { selectorSheet = .rewriteLLM }
                )

                FeaturePromptSection(
                    title: featureSettingsLocalized("Rewrite Prompt"),
                    text: promptBinding(
                        get: { featureSettings.rewrite.prompt },
                        set: { featureSettings.rewrite.prompt = $0 },
                        kind: .rewrite
                    ),
                    defaultText: AppPromptDefaults.text(for: .rewrite),
                    variables: ModelSettingsPromptVariables.rewrite,
                    guidance: "",
                    persistChanges: saveFeatureSettings
                )

            }
        }
    }
}
