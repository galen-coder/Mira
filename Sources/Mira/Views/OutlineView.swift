import SwiftUI

struct OutlineView: View {
    let text: String
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

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
                    Text("\(L10n.tr("outline.line", language: language)) \(item.line)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, CGFloat(max(0, item.level - 1)) * 10)
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("outline.title", language: language))
                    .font(.headline)
                Text("\(outline.count) \(L10n.tr("outline.headings", language: language))")
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
