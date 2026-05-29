import SwiftUI

struct MarkdownEditor: View {
    @Binding var text: String
    @Binding var command: MarkdownEditCommand?

    let searchText: String
    let isFocusMode: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MarkdownSourceEditor(
                text: $text,
                command: $command,
                isFocusMode: isFocusMode,
                searchText: searchText
            )

            if !searchText.isEmpty {
                Text("\(matchCount) matches")
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
