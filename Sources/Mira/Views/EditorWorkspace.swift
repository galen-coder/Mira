import SwiftUI

struct EditorWorkspace: View {
    @Binding var text: String
    @Binding var mode: EditorMode
    @Binding var searchText: String
    @Binding var previewFontSize: Double
    @Binding var editCommand: MarkdownEditCommand?

    let isFocusMode: Bool

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
                    MarkdownEditor(text: $text, command: $editCommand, searchText: searchText, isFocusMode: isFocusMode)
                case .split:
                    HSplitView {
                        MarkdownEditor(text: $text, command: $editCommand, searchText: searchText, isFocusMode: isFocusMode)
                            .frame(minWidth: 360)
                        MarkdownPreview(text: text, searchText: searchText, fontSize: previewFontSize, isFocusMode: isFocusMode)
                            .frame(minWidth: 360)
                    }
                case .preview:
                    MarkdownPreview(text: text, searchText: searchText, fontSize: previewFontSize, isFocusMode: isFocusMode)
                }
            }
            .overlay(alignment: .bottom) {
                StatusBar(stats: stats)
            }
        }
    }
}
