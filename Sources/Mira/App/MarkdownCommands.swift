import SwiftUI

struct MarkdownCommands: Commands {
    @FocusedBinding(\.editorMode) private var editorMode
    @FocusedBinding(\.showsOutline) private var showsOutline
    @FocusedBinding(\.isFocusMode) private var isFocusMode
    @FocusedBinding(\.markdownEditCommand) private var markdownEditCommand

    var body: some Commands {
        CommandMenu("Markdown") {
            Picker("View Mode", selection: Binding(
                get: { editorMode ?? .split },
                set: { editorMode = $0 }
            )) {
                ForEach(EditorMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button("Toggle Outline") {
                showsOutline?.toggle()
            }
            .keyboardShortcut("0", modifiers: [.command, .option])

            Button("Focus Mode") {
                isFocusMode?.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Button("Bold") {
                run(.bold)
            }
            .keyboardShortcut("b", modifiers: [.command])

            Button("Italic") {
                run(.italic)
            }
            .keyboardShortcut("i", modifiers: [.command])

            Button("Inline Code") {
                run(.inlineCode)
            }
            .keyboardShortcut("e", modifiers: [.command])

            Button("Code Block") {
                run(.codeBlock)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button("Heading 1") {
                run(.heading(1))
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Heading 2") {
                run(.heading(2))
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Heading 3") {
                run(.heading(3))
            }
            .keyboardShortcut("3", modifiers: [.command])

            Divider()

            Button("Quote") {
                run(.quote)
            }
            .keyboardShortcut("q", modifiers: [.command, .shift])

            Button("Bullet List") {
                run(.unorderedList)
            }
            .keyboardShortcut("8", modifiers: [.command, .shift])

            Button("Numbered List") {
                run(.orderedList)
            }
            .keyboardShortcut("7", modifiers: [.command, .shift])

            Button("Task List") {
                run(.taskList)
            }
            .keyboardShortcut("9", modifiers: [.command, .shift])

            Divider()

            Button("Link") {
                run(.link)
            }
            .keyboardShortcut("k", modifiers: [.command])

            Button("Image") {
                run(.image)
            }

            Button("Table") {
                run(.table)
            }
        }
    }

    private func run(_ kind: MarkdownEditCommand.Kind) {
        markdownEditCommand = MarkdownEditCommand(kind: kind)
    }
}
