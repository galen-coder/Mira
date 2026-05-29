import Foundation

struct MarkdownBlock: Identifiable, Equatable {
    enum Kind: Equatable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case quote(String)
        case unorderedList([String])
        case orderedList([String])
        case taskList([TaskListItem])
        case table(headers: [String], rows: [[String]])
        case image(alt: String, source: String)
        case code(language: String?, text: String)
        case divider
        case blank
    }

    let id = UUID()
    let line: Int
    let kind: Kind
}

struct TaskListItem: Equatable {
    let isComplete: Bool
    let text: String
}

struct OutlineItem: Identifiable, Equatable {
    let id = UUID()
    let line: Int
    let level: Int
    let title: String
}
