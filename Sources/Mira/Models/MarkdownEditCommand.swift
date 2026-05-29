import Foundation

struct MarkdownEditCommand: Identifiable, Equatable {
    enum Kind: Equatable {
        case heading(Int)
        case bold
        case italic
        case inlineCode
        case codeBlock
        case quote
        case unorderedList
        case orderedList
        case taskList
        case link
        case image
        case table
    }

    let id = UUID()
    let kind: Kind
}
