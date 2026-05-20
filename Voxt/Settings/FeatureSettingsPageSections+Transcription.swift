import SwiftUI

extension FeatureSettingsView {
    var transcriptionContent: some View {
        featurePage(
            title: "",
            subtitle: "",
            icon: "",
            pills: transcriptionPills
        ) {
            FeatureSettingsCard(title: featureSettingsLocalized("Model Pipeline")) {
                FeatureSelectorRow(
                    title: featureSettingsLocalized("Audio Model"),
                    value: asrSelectionSummary(featureSettings.transcription.asrSelectionID),
                    action: { selectorSheet = .transcriptionASR }
                )

                FeatureToggleRow(
                    title: featureSettingsLocalized("Text Enhancement"),
                    detail: featureSettingsLocalized("Clean punctuation, structure, and readability."),
                    isOn: transcriptionLLMEnabledBinding
                )

                if featureSettings.transcription.llmEnabled {
                    FeatureSelectorRow(
                        title: featureSettingsLocalized("Enhancement Model"),
                        value: llmSelectionSummary(featureSettings.transcription.llmSelectionID),
                        action: { selectorSheet = .transcriptionLLM }
                    )
                    FeaturePromptSection(
                        title: featureSettingsLocalized("Enhancement Prompt"),
                        text: promptBinding(
                            get: { featureSettings.transcription.prompt },
                            set: { featureSettings.transcription.prompt = $0 },
                            kind: .enhancement
                        ),
                        defaultText: AppPromptDefaults.text(for: .enhancement),
                        variables: ModelSettingsPromptVariables.enhancement,
                        guidance: "",
                        persistChanges: saveFeatureSettings
                    )
                }

                FeatureToggleRow(
                    title: featureSettingsLocalized("Notes Feature"),
                    detail: featureSettingsLocalized("Save useful transcript segments as separate notes while recording."),
                    isOn: binding(
                        get: { featureSettings.transcription.notes.enabled },
                        set: { featureSettings.transcription.notes.enabled = $0 }
                    )
                )
            }
        }
    }

    var noteContent: some View {
        featurePage(
            title: "",
            subtitle: "",
            icon: "",
            pills: notePills
        ) {
            FeatureSettingsCard(title: "") {
                FeatureSelectorRow(
                    title: featureSettingsLocalized("Summary Model"),
                    value: llmSelectionSummary(featureSettings.transcription.notes.titleModelSelectionID),
                    action: { selectorSheet = .transcriptionNoteTitle }
                )

                FeatureNoteAudioRow(
                    title: featureSettingsLocalized("Note Audio"),
                    detail: "",
                    isOn: binding(
                        get: { featureSettings.transcription.notes.soundEnabled },
                        set: { featureSettings.transcription.notes.soundEnabled = $0 }
                    ),
                    preset: binding(
                        get: { featureSettings.transcription.notes.soundPreset },
                        set: { featureSettings.transcription.notes.soundPreset = $0 }
                    ),
                    onTrySound: {
                        interactionSoundPlayer.playPreview(preset: featureSettings.transcription.notes.soundPreset)
                    }
                )

                FeatureNoteShortcutRow(
                    title: featureSettingsLocalized("Trigger Key"),
                    detail: "",
                    shortcut: binding(
                        get: { featureSettings.transcription.notes.triggerShortcut },
                        set: { featureSettings.transcription.notes.triggerShortcut = $0 }
                    )
                )

                FeatureSettingSection(
                    title: "",
                    detail: ""
                ) {
                    noteObsidianSyncSection
                }

                FeatureSettingSection(
                    title: "",
                    detail: ""
                ) {
                    noteRemindersSyncSection
                }
            }
        }
    }
}
