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

    let id: String
    let line: Int
    let kind: Kind

    init(line: Int, kind: Kind) {
        self.line = line
        self.kind = kind
        id = "\(line)-\(kind.stableKey)"
    }
}

struct TaskListItem: Equatable {
    let isComplete: Bool
    let text: String
}

struct OutlineItem: Identifiable, Equatable {
    var id: String { "\(line)-\(level)-\(title)" }
    let line: Int
    let level: Int
    let title: String
}

private extension MarkdownBlock.Kind {
    var stableKey: String {
        switch self {
        case let .heading(level, text):
            "heading-\(level)-\(text)"
        case let .paragraph(text):
            "paragraph-\(text)"
        case let .quote(text):
            "quote-\(text)"
        case let .unorderedList(items):
            "ul-\(items.joined(separator: "\u{1F}"))"
        case let .orderedList(items):
            "ol-\(items.joined(separator: "\u{1F}"))"
        case let .taskList(items):
            "tasks-\(items.map { "\($0.isComplete)-\($0.text)" }.joined(separator: "\u{1F}"))"
        case let .table(headers, rows):
            "table-\(headers.joined(separator: "\u{1F}"))-\(rows.map { $0.joined(separator: "\u{1E}") }.joined(separator: "\u{1F}"))"
        case let .image(alt, source):
            "image-\(alt)-\(source)"
        case let .code(language, text):
            "code-\(language ?? "")-\(text)"
        case .divider:
            "divider"
        case .blank:
            "blank"
        }
    }
}
