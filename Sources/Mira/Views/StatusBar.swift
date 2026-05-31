import SwiftUI

struct StatusBar: View {
    let stats: DocumentStats
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

    var body: some View {
        HStack(spacing: 14) {
            Label("\(stats.words) \(L10n.tr("stats.words", language: language))", systemImage: "text.word.spacing")
            Label("\(stats.characters) \(L10n.tr("stats.characters", language: language))", systemImage: "character.cursor.ibeam")
            Label("\(stats.headings) \(L10n.tr("stats.headings", language: language))", systemImage: "list.bullet.indent")
            Label("\(stats.readingMinutes) \(L10n.tr("stats.readingTime", language: language))", systemImage: "clock")
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
