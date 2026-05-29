import SwiftUI

struct StatusBar: View {
    let stats: DocumentStats

    var body: some View {
        HStack(spacing: 14) {
            Label("\(stats.words) words", systemImage: "text.word.spacing")
            Label("\(stats.characters) chars", systemImage: "character.cursor.ibeam")
            Label("\(stats.headings) headings", systemImage: "list.bullet.indent")
            Label("\(stats.readingMinutes) min read", systemImage: "clock")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar, in: Capsule())
        .padding(.bottom, 10)
    }
}
