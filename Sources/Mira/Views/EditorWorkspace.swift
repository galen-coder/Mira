import SwiftUI

struct EditorWorkspace: View {
    @Binding var text: String
    let documentURL: URL?
    @Binding var mode: EditorMode
    @Binding var searchText: String
    @Binding var previewFontSize: Double
    @Binding var editCommand: MarkdownEditCommand?
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.system.rawValue

    let isFocusMode: Bool
    @StateObject private var scrollSync = ScrollSyncState()
    @State private var previewText = ""
    @State private var previewUpdateTask: Task<Void, Never>?

    private var language: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

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
                    Label(L10n.tr("toolbar.previewSize", language: language), systemImage: "textformat.size")
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
                        MarkdownPreview(text: previewText, documentURL: documentURL, searchText: searchText, fontSize: previewFontSize, isFocusMode: isFocusMode, scrollSync: scrollSync)
                            .frame(minWidth: 360)
                    }
                case .preview:
                    MarkdownPreview(text: previewText, documentURL: documentURL, searchText: searchText, fontSize: previewFontSize, isFocusMode: isFocusMode, scrollSync: scrollSync)
                }
            }
            .overlay(alignment: .bottom) {
                StatusBar(stats: stats)
            }
        }
        .onAppear {
            previewText = text
        }
        .onChange(of: text) { _, newValue in
            schedulePreviewUpdate(newValue)
        }
        .onDisappear {
            previewUpdateTask?.cancel()
        }
    }

    private func schedulePreviewUpdate(_ newValue: String) {
        previewUpdateTask?.cancel()
        previewUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                previewText = newValue
            }
        }
    }
}
