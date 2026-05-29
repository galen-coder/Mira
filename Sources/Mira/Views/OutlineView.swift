import SwiftUI

struct OutlineView: View {
    let text: String

    private var outline: [OutlineItem] {
        MarkdownParser.outline(from: text)
    }

    var body: some View {
        List(outline) { item in
            HStack(spacing: 8) {
                Image(systemName: item.level <= 2 ? "textformat.size" : "number")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .lineLimit(1)
                    Text("Line \(item.line)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, CGFloat(max(0, item.level - 1)) * 10)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Outline")
                    .font(.headline)
                Text("\(outline.count) headings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}
