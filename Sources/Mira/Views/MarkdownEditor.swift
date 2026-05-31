import SwiftUI

struct MarkdownEditor: View {
    @Binding var text: String
    @Binding var command: MarkdownEditCommand?

    let documentURL: URL?
    let searchText: String
    let isFocusMode: Bool
    @ObservedObject var scrollSync: ScrollSyncState
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MarkdownSourceEditor(
                text: $text,
                command: $command,
                documentURL: documentURL,
                isFocusMode: isFocusMode,
                searchText: searchText,
                scrollSync: scrollSync
            )

            if !searchText.isEmpty {
                Text("\(matchCount) \(L10n.tr("search.matches", language: language))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .padding(16)
            }
        }
    }

    private var matchCount: Int {
        guard !searchText.isEmpty else { return 0 }
        return text.localizedStandardRangeCount(of: searchText)
    }
}

private extension String {
    func localizedStandardRangeCount(of needle: String) -> Int {
        var count = 0
        var searchRange = startIndex..<endIndex

        while let range = range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<endIndex
        }

        return count
    }
}
