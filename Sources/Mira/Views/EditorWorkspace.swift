import SwiftUI

struct EditorWorkspace: View {
    @Binding var text: String
    let documentURL: URL?
    @Binding var mode: EditorMode
    @Binding var searchText: String
    @Binding var previewFontSize: Double
    @Binding var editCommand: MarkdownEditCommand?

    let isFocusMode: Bool
    @StateObject private var scrollSync = ScrollSyncState()

    private var stats: DocumentStats {
        MarkdownParser.stats(for: text)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SearchField(text: $searchText)
                    .frame(maxWidth: 280)

                Spacer()

                Stepper(value: $previewFontSize, in: 13...22, step: 1) {
                    Label("Preview Size", systemImage: "textformat.size")
                }
                .labelStyle(.iconOnly)
                .help("Preview text size")
                .disabled(mode == .edit)
            }
            .padding(.horizontal, isFocusMode ? 36 : 18)
            .padding(.vertical, 10)
            .background(.bar)

            Group {
                switch mode {
                case .edit:
                    MarkdownEditor(text: $text, command: $editCommand, documentURL: documentURL, searchText: searchText, isFocusMode: isFocusMode, scrollSync: scrollSync)
                case .split:
                    HSplitView {
                        MarkdownEditor(text: $text, command: $editCommand, documentURL: documentURL, searchText: searchText, isFocusMode: isFocusMode, scrollSync: scrollSync)
                            .frame(minWidth: 360)
                        MarkdownPreview(text: text, documentURL: documentURL, searchText: searchText, fontSize: previewFontSize, isFocusMode: isFocusMode, scrollSync: scrollSync)
                            .frame(minWidth: 360)
                    }
                case .preview:
                    MarkdownPreview(text: text, documentURL: documentURL, searchText: searchText, fontSize: previewFontSize, isFocusMode: isFocusMode, scrollSync: scrollSync)
                }
            }
            .overlay(alignment: .bottom) {
                StatusBar(stats: stats)
            }
        }
    }
}
