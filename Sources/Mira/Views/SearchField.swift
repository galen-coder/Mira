import SwiftUI

struct SearchField: View {
    @Binding var text: String
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(L10n.tr("search.placeholder", language: language), text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 7))
    }
}
