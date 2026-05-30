import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let documentURL: URL?

    @AppStorage("editorMode") private var storedMode = EditorMode.split.rawValue
    @AppStorage("showsOutline") private var showsOutline = true
    @AppStorage("isFocusMode") private var isFocusMode = false
    @AppStorage("previewFontSize") private var previewFontSize = 16.0
    @SceneStorage("searchText") private var searchText = ""
    @State private var editCommand: MarkdownEditCommand?

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
        .toolbar {
            ToolbarItemGroup {
                Toggle(isOn: $showsOutline) {
                    Label("Outline", systemImage: "sidebar.leading")
                }
                .help("Show outline")

                Picker("Mode", selection: mode) {
                    ForEach(EditorMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
                .help("Switch writing view")

                Toggle(isOn: $isFocusMode) {
                    Label("Focus", systemImage: "scope")
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
                    Button("Heading 1") { editCommand = MarkdownEditCommand(kind: .heading(1)) }
                    Button("Heading 2") { editCommand = MarkdownEditCommand(kind: .heading(2)) }
                    Button("Heading 3") { editCommand = MarkdownEditCommand(kind: .heading(3)) }
                } label: {
                    Image(systemName: "textformat.size")
                }
                .help("Heading")

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
