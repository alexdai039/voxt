import AppKit
import SwiftUI
import UniformTypeIdentifiers

private func logsViewerLocalized(_ key: String) -> String {
    AppLocalization.localizedString(key)
}

private func logsViewerLocalizedKey(_ key: String) -> LocalizedStringKey {
    LocalizedStringKey(logsViewerLocalized(key))
}

struct LogsViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var latestLogsText = ""
    @State private var logsStatusMessage = ""
    @State private var toastMessage = ""
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var isExportingLogs = false
    @State private var logExportDocument = LogExportDocument(text: "")
    @State private var logExportFilename = "voxt-log.txt"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(logsViewerLocalizedKey("Export Logs"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(logsViewerLocalized("Latest 1000"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )

                Spacer(minLength: 0)

                Button(logsViewerLocalized("Refresh")) {
                    refreshLogs()
                }
                .buttonStyle(SettingsCompactActionButtonStyle())

                Button(logsViewerLocalized("Copy")) {
                    copyLogs()
                }
                .buttonStyle(SettingsCompactActionButtonStyle())

                Button(logsViewerLocalized("Export")) {
                    prepareLogExport()
                }
                .buttonStyle(SettingsCompactActionButtonStyle())

                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(SettingsCompactIconButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 4)

            if !logsStatusMessage.isEmpty {
                Text(logsStatusMessage)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }

            ScrollView([.vertical, .horizontal]) {
                Text(latestLogsText)
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.86))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(12)
            }
            .frame(maxWidth: .infinity, minHeight: 420, idealHeight: 440, maxHeight: 440)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(SettingsUIStyle.subtleBorderColor, lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 680, idealWidth: 720, maxWidth: 760, minHeight: 500, idealHeight: 540)
        .fileExporter(
            isPresented: $isExportingLogs,
            document: logExportDocument,
            contentType: .plainText,
            defaultFilename: logExportFilename
        ) { result in
            switch result {
            case .success:
                logsStatusMessage = ""
                showToast(logsViewerLocalized("Exported latest 1000 log lines."))
            case .failure(let error):
                logsStatusMessage = AppLocalization.format(
                    "Log export failed: %@",
                    error.localizedDescription
                )
            }
        }
        .overlay(alignment: .top) {
            if !toastMessage.isEmpty {
                ModelDebugToast(message: toastMessage) {
                    dismissToast()
                }
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: toastMessage)
        .onAppear {
            refreshLogs()
        }
    }

    private func refreshLogs() {
        latestLogsText = VoxtLog.latestLogDisplayText(limit: 1000)
        logsStatusMessage = ""
    }

    private func copyLogs() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(latestLogsText, forType: .string)
        logsStatusMessage = ""
        showToast(logsViewerLocalized("Copied to clipboard"))
    }

    private func prepareLogExport() {
        let payload = VoxtLog.latestLogExportPayload(limit: 1000)
        logExportDocument = LogExportDocument(text: payload.content)
        logExportFilename = payload.filename
        isExportingLogs = true
    }

    private func showToast(_ message: String, duration: TimeInterval = 2.2) {
        toastDismissTask?.cancel()
        toastMessage = message
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            toastMessage = ""
        }
    }

    private func dismissToast() {
        toastDismissTask?.cancel()
        toastMessage = ""
    }
}
