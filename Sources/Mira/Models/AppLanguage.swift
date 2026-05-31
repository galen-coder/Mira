import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            "System"
        case .english:
            "English"
        case .simplifiedChinese:
            "简体中文"
        }
    }
}
