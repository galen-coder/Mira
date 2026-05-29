import Foundation

enum EditorMode: String, CaseIterable, Identifiable {
    case edit
    case split
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit:
            "Edit"
        case .split:
            "Split"
        case .preview:
            "Preview"
        }
    }

    var systemImage: String {
        switch self {
        case .edit:
            "pencil.line"
        case .split:
            "rectangle.split.2x1"
        case .preview:
            "doc.richtext"
        }
    }
}
