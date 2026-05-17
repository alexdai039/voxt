import SwiftUI

struct DictionarySettingsHeaderCard: View {
    let historyScanProgress: DictionaryHistoryScanProgress
    let suggestionActionMessage: String?
    let onOpenIngest: () -> Void
    let onOpenSettings: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let historyScanSummaryText: (Date) -> String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 16) {
                    Button(AppLocalization.localizedString("One-Click Ingest")) {
                        onOpenIngest()
                    }
                    .buttonStyle(SettingsPillButtonStyle())

                    Spacer(minLength: 12)

                    Button {
                        onOpenSettings()
                    } label: {
                        Text(AppLocalization.localizedString("Settings"))
                    }
                    .buttonStyle(SettingsPillButtonStyle())
                    .help(AppLocalization.localizedString("Dictionary Advanced Settings"))

                    DictionaryHeaderActionMenuButton(
                        actions: [
                            DictionaryHeaderMenuAction(title: AppLocalization.localizedString("Import"), handler: onImport),
                            DictionaryHeaderMenuAction(title: AppLocalization.localizedString("Export"), handler: onExport)
                        ]
                    )
                    .frame(width: 28, height: 28)
                    .help(AppLocalization.localizedString("More"))
                }

                DictionarySettingsHeaderStatus(
                    historyScanProgress: historyScanProgress,
                    suggestionActionMessage: suggestionActionMessage,
                    historyScanSummaryText: historyScanSummaryText
                )
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DictionarySettingsHeaderStatus: View {
    let historyScanProgress: DictionaryHistoryScanProgress
    let suggestionActionMessage: String?
    let historyScanSummaryText: (Date) -> String

    var body: some View {
        if let errorMessage = historyScanProgress.errorMessage,
           !errorMessage.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                Text(AppLocalization.localizedString("Review the ingest prompt in One-Click Ingest, then try again."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let lastRunAt = historyScanProgress.lastRunAt {
            Text(historyScanSummaryText(lastRunAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let suggestionActionMessage, !suggestionActionMessage.isEmpty {
            Text(suggestionActionMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct DictionaryEntriesCard: View {
    @Binding var selectedFilter: DictionaryFilter
    let visibleEntries: [DictionaryEntry]
    let totalEntryCount: Int
    let searchText: String
    let isLoadingEntries: Bool
    let onSearch: () -> Void
    let onClearSearch: () -> Void
    let onLoadMore: () -> Void
    let onCreate: () -> Void
    let onClearAll: () -> Void
    let onEdit: (DictionaryEntry) -> Void
    let onDelete: (DictionaryEntry) -> Void

    private let columnCount = 3

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    DictionaryFilterPicker(selectedFilter: $selectedFilter)

                    Spacer(minLength: 12)

                    Button {
                        onSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(SettingsCompactIconButtonStyle())
                    .help(AppLocalization.localizedString("Search Dictionary"))

                    Button(AppLocalization.localizedString("Create")) {
                        onCreate()
                    }
                    .buttonStyle(SettingsPillButtonStyle())

                    Button(AppLocalization.localizedString("Clean All"), role: .destructive) {
                        onClearAll()
                    }
                    .buttonStyle(SettingsStatusButtonStyle(tint: .red))
                    .disabled(totalEntryCount == 0)
                }

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(spacing: 8) {
                        Text(AppLocalization.format("Filtered by \"%@\"", searchText))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button(AppLocalization.localizedString("Clear")) {
                            onClearSearch()
                        }
                        .buttonStyle(.plain)
                    }
                }

                if visibleEntries.isEmpty && !isLoadingEntries {
                    Text(emptyStateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    PagedVerticalList(
                        items: entryRows,
                        totalCount: totalRowCount,
                        rowHeight: 34,
                        rowSpacing: 8,
                        isLoading: isLoadingEntries,
                        onLoadMore: onLoadMore
                    ) { row in
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(row.entries) { entry in
                                DictionaryRow(
                                    entry: entry,
                                    onEdit: { onEdit(entry) },
                                    onDelete: { onDelete(entry) }
                                )
                            }

                            ForEach(0..<row.placeholderCount, id: \.self) { _ in
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: .infinity, alignment: .top)
                }

            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var emptyStateText: String {
        if !isSearchActive {
            return AppLocalization.localizedString("No dictionary terms yet.")
        }
        return AppLocalization.localizedString("No dictionary terms match this search.")
    }

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var entryRows: [DictionaryEntryGridRow] {
        stride(from: 0, to: visibleEntries.count, by: columnCount).map { startIndex in
            let endIndex = min(startIndex + columnCount, visibleEntries.count)
            return DictionaryEntryGridRow(
                entries: Array(visibleEntries[startIndex..<endIndex]),
                columnCount: columnCount
            )
        }
    }

    private var totalRowCount: Int {
        guard totalEntryCount > 0 else { return 0 }
        return Int(ceil(Double(totalEntryCount) / Double(columnCount)))
    }
}

private struct DictionaryEntryGridRow: Identifiable {
    let entries: [DictionaryEntry]
    let columnCount: Int

    var id: String {
        entries.map { $0.id.uuidString }.joined(separator: "-")
    }

    var placeholderCount: Int {
        max(0, columnCount - entries.count)
    }
}
