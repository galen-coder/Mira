import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let documentURL: URL?

    @AppStorage("editorMode") private var storedMode = EditorMode.split.rawValue
    @AppStorage("showsOutline") private var showsOutline = true
    @AppStorage("isFocusMode") private var isFocusMode = false
    @AppStorage("previewFontSize") private var previewFontSize = 16.0
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.system.rawValue
    @SceneStorage("searchText") private var searchText = ""
    @State private var editCommand: MarkdownEditCommand?

    private var language: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

    private var mode: Binding<EditorMode> {
        Binding(
            get: { EditorMode(rawValue: storedMode) ?? .split },
            set: { storedMode = $0.rawValue }
        )
    }

    var body: some View {
        HSplitView {
            if showsOutline && !isFocusMode {
                OutlineView(text: document.text)
                    .frame(minWidth: 190, idealWidth: 230, maxWidth: 280)
            }

            EditorWorkspace(
                text: $document.text,
                documentURL: documentURL,
                mode: mode,
                searchText: $searchText,
                previewFontSize: $previewFontSize,
                editCommand: $editCommand,
                isFocusMode: isFocusMode
            )
            .frame(minWidth: 620)
        }
        .focusedSceneValue(\.editorMode, mode)
        .focusedSceneValue(\.showsOutline, $showsOutline)
        .focusedSceneValue(\.isFocusMode, $isFocusMode)
        .focusedSceneValue(\.markdownEditCommand, $editCommand)
        .background {
            WindowLifecycleView(
                documentURL: documentURL,
                isDocumentEmpty: document.text.isEmpty,
                documentText: document.text
            )
                .frame(width: 0, height: 0)
        }
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $showsOutline) {
                    Label(L10n.tr("toolbar.outline", language: language), systemImage: "sidebar.leading")
                }
                .help("Show outline")

                Picker(L10n.tr("toolbar.mode", language: language), selection: mode) {
                    ForEach(EditorMode.allCases) { mode in
                        Label(mode.localizedTitle(language: language), systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .help("Switch writing view")

                Toggle(isOn: $isFocusMode) {
                    Label(L10n.tr("toolbar.focus", language: language), systemImage: "scope")
                }
                .help("Focus mode")
            }

            ToolbarItemGroup {
                Button {
                    editCommand = MarkdownEditCommand(kind: .bold)
                } label: {
                    Image(systemName: "bold")
                }
                .help("Bold")

                Button {
                    editCommand = MarkdownEditCommand(kind: .italic)
                } label: {
                    Image(systemName: "italic")
                }
                .help("Italic")

                Button {
                    editCommand = MarkdownEditCommand(kind: .inlineCode)
                } label: {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                }
                .help("Inline code")

                Button {
                    editCommand = MarkdownEditCommand(kind: .codeBlock)
                } label: {
                    Image(systemName: "curlybraces.square")
                }
                .help("Code block")

                Button {
                    editCommand = MarkdownEditCommand(kind: .link)
                } label: {
                    Image(systemName: "link")
                }
                .help("Link")
            }

            ToolbarItemGroup {
                Menu {
                    Button(L10n.tr("command.heading1", language: language)) { editCommand = MarkdownEditCommand(kind: .heading(1)) }
                    Button(L10n.tr("command.heading2", language: language)) { editCommand = MarkdownEditCommand(kind: .heading(2)) }
                    Button(L10n.tr("command.heading3", language: language)) { editCommand = MarkdownEditCommand(kind: .heading(3)) }
                } label: {
                    Image(systemName: "textformat.size")
                }
                .help(L10n.tr("toolbar.heading", language: language))

                Button {
                    editCommand = MarkdownEditCommand(kind: .quote)
                } label: {
                    Image(systemName: "quote.opening")
                }
                .help("Quote")

                Button {
                    editCommand = MarkdownEditCommand(kind: .unorderedList)
                } label: {
                    Image(systemName: "list.bullet")
                }
                .help("Bullet list")

                Button {
                    editCommand = MarkdownEditCommand(kind: .orderedList)
                } label: {
                    Image(systemName: "list.number")
                }
                .help("Numbered list")

                Button {
                    editCommand = MarkdownEditCommand(kind: .taskList)
                } label: {
                    Image(systemName: "checklist")
                }
                .help("Task list")

                Button {
                    editCommand = MarkdownEditCommand(kind: .table)
                } label: {
                    Image(systemName: "tablecells")
                }
                .help("Table")
            }
        }
    }
}
