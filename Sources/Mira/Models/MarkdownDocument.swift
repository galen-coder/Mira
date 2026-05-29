import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown, .plainText] }

    var text: String

    init(text: String = MarkdownDocument.sampleText) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            text = ""
            return
        }

        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private extension MarkdownDocument {
    static let sampleText = """
    # Hello Markdown

    A quiet Markdown editor for macOS, shaped around the things that make Typora feel good: writing first, preview close at hand, and very little noise.

    ## Core gestures

    - Write in source mode when you want precision.
    - Keep split mode open while drafting.
    - Switch to preview when you want to read the page.

    - [x] Use Markdown shortcuts from the toolbar.
    - [ ] Turn this draft into a real document.

    > The best writing tools get out of the way, but keep the craft close.

    | Mode | Best for |
    | --- | --- |
    | Edit | Precise source writing |
    | Split | Drafting with live feedback |
    | Preview | Reading and polishing |

    ```swift
    let title = "Hello Markdown"
    print(title)
    ```

    ## Next idea

    Add your own notes here.
    """
}
