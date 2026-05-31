import SwiftUI

struct MarkdownCommands: Commands {
    @FocusedBinding(\.editorMode) private var editorMode
    @FocusedBinding(\.showsOutline) private var showsOutline
    @FocusedBinding(\.isFocusMode) private var isFocusMode
    @FocusedBinding(\.markdownEditCommand) private var markdownEditCommand
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.system.rawValue

    private var language: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(L10n.tr("command.openRecentClosed", language: language)) {
                RecentDocumentOpener.openRecentClosedDocument()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
        }

        CommandMenu("Markdown") {
            Picker(L10n.tr("toolbar.mode", language: language), selection: Binding(
                get: { editorMode ?? .split },
                set: { editorMode = $0 }
            )) {
                ForEach(EditorMode.allCases) { mode in
                    Text(mode.localizedTitle(language: language)).tag(mode)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button(L10n.tr("command.toggleOutline", language: language)) {
                showsOutline?.toggle()
            }
            .keyboardShortcut("0", modifiers: [.command, .option])

            Button(L10n.tr("command.focusMode", language: language)) {
                isFocusMode?.toggle()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Divider()

            Button(L10n.tr("command.bold", language: language)) {
                run(.bold)
            }
            .keyboardShortcut("b", modifiers: [.command])

            Button(L10n.tr("command.italic", language: language)) {
                run(.italic)
            }
            .keyboardShortcut("i", modifiers: [.command])

            Button(L10n.tr("command.inlineCode", language: language)) {
                run(.inlineCode)
            }
            .keyboardShortcut("e", modifiers: [.command])

            Button(L10n.tr("command.codeBlock", language: language)) {
                run(.codeBlock)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Divider()

            Button(L10n.tr("command.heading1", language: language)) {
                run(.heading(1))
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button(L10n.tr("command.heading2", language: language)) {
                run(.heading(2))
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button(L10n.tr("command.heading3", language: language)) {
                run(.heading(3))
            }
            .keyboardShortcut("3", modifiers: [.command])

            Divider()

            Button(L10n.tr("command.quote", language: language)) {
                run(.quote)
            }
            .keyboardShortcut("q", modifiers: [.command, .shift])

            Button(L10n.tr("command.bulletList", language: language)) {
                run(.unorderedList)
            }
            .keyboardShortcut("8", modifiers: [.command, .shift])

            Button(L10n.tr("command.numberedList", language: language)) {
                run(.orderedList)
            }
            .keyboardShortcut("7", modifiers: [.command, .shift])

            Button(L10n.tr("command.taskList", language: language)) {
                run(.taskList)
            }
            .keyboardShortcut("9", modifiers: [.command, .shift])

            Divider()

            Button(L10n.tr("command.link", language: language)) {
                run(.link)
            }
            .keyboardShortcut("k", modifiers: [.command])

            Button(L10n.tr("command.image", language: language)) {
                run(.image)
            }

            Button(L10n.tr("command.table", language: language)) {
                run(.table)
            }
        }
    }

    private func run(_ kind: MarkdownEditCommand.Kind) {
        markdownEditCommand = MarkdownEditCommand(kind: kind)
    }
}
