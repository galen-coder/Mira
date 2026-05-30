import AppKit
import SwiftUI

struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var command: MarkdownEditCommand?

    let documentURL: URL?
    let isFocusMode: Bool
    let searchText: String
    @ObservedObject var scrollSync: ScrollSyncState

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, command: $command, scrollSync: scrollSync)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.onPasteImage = { textView in
            context.coordinator.pasteImage(from: .general, into: textView, documentURL: documentURL)
        }
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.usesFontPanel = false
        textView.importsGraphics = false
        textView.string = text
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textContainerInset = NSSize(width: isFocusMode ? 72 : 28, height: 28)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .controlAccentColor
        textView.typingAttributes = context.coordinator.baseTypingAttributes

        scrollView.documentView = textView
        context.coordinator.configureScrollSync(scrollView)
        context.coordinator.applyHighlighting(to: textView, searchText: searchText)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }
        textView.onPasteImage = { textView in
            context.coordinator.pasteImage(from: .general, into: textView, documentURL: documentURL)
        }

        textView.textContainerInset = NSSize(width: isFocusMode ? 72 : 28, height: 28)
        textView.backgroundColor = .textBackgroundColor
        scrollView.backgroundColor = .textBackgroundColor

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selectedRange.location, (text as NSString).length), length: 0))
        }

        if let command, context.coordinator.lastCommandID != command.id {
            context.coordinator.lastCommandID = command.id
            context.coordinator.apply(command, to: textView)
            DispatchQueue.main.async {
                self.command = nil
            }
        }

        context.coordinator.applyHighlighting(to: textView, searchText: searchText)
        context.coordinator.applySyncedScrollIfNeeded(to: scrollView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var command: MarkdownEditCommand?
        private let scrollSync: ScrollSyncState

        var lastCommandID: UUID?
        private var isHighlighting = false
        private var isApplyingSyncedScroll = false
        private var lastAppliedScrollRevision = -1

        init(text: Binding<String>, command: Binding<MarkdownEditCommand?>, scrollSync: ScrollSyncState) {
            _text = text
            _command = command
            self.scrollSync = scrollSync
        }

        var baseTypingAttributes: [NSAttributedString.Key: Any] {
            [
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle
            ]
        }

        private var paragraphStyle: NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 5
            return style
        }

        func configureScrollSync(_ scrollView: NSScrollView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.removeObserver(
                self,
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(scrollViewDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        @objc private func scrollViewDidScroll(_ notification: Notification) {
            guard !isApplyingSyncedScroll,
                  let clipView = notification.object as? NSClipView,
                  let textView = clipView.documentView as? NSTextView else {
                return
            }

            scrollSync.update(from: .editor, ratio: scrollRatio(for: textView, in: clipView))
        }

        func applySyncedScrollIfNeeded(to scrollView: NSScrollView) {
            guard scrollSync.source == .preview,
                  scrollSync.revision != lastAppliedScrollRevision,
                  let textView = scrollView.documentView as? NSTextView else {
                return
            }

            lastAppliedScrollRevision = scrollSync.revision
            scroll(to: scrollSync.ratio, textView: textView, in: scrollView)
        }

        func textDidChange(_ notification: Notification) {
            guard !isHighlighting, let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }

        func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard replacementString == "`",
                  affectedCharRange.length == 0,
                  shouldCompleteCodeFence(in: textView.string, at: affectedCharRange.location) else {
                return true
            }

            textView.insertText("`\n\n```", replacementRange: affectedCharRange)
            textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))
            text = textView.string
            applyHighlighting(to: textView, searchText: "")
            return false
        }

        func pasteImage(from pasteboard: NSPasteboard, into textView: NSTextView, documentURL: URL?) -> Bool {
            do {
                guard let markdown = try ClipboardImageAssetWriter.markdownImageFromPasteboard(pasteboard, documentURL: documentURL) else {
                    return false
                }

                insertImageMarkdown(markdown, into: textView)
                return true
            } catch let error as ClipboardImageAssetWriter.WriteError {
                return handleImagePasteWriteError(error, pasteboard: pasteboard, textView: textView, documentURL: documentURL)
            } catch {
                presentPasteImageError(error)
                return true
            }
        }

        private func handleImagePasteWriteError(
            _ error: ClipboardImageAssetWriter.WriteError,
            pasteboard: NSPasteboard,
            textView: NSTextView,
            documentURL: URL?
        ) -> Bool {
            switch error {
            case let .assetsDirectoryMissing(url):
                guard confirmCreateAssetsDirectory(url) else {
                    return true
                }

                do {
                    guard let markdown = try ClipboardImageAssetWriter.markdownImageFromPasteboard(
                        pasteboard,
                        documentURL: documentURL,
                        createAssetsDirectory: true
                    ) else {
                        return false
                    }

                    insertImageMarkdown(markdown, into: textView)
                } catch {
                    presentPasteImageError(error)
                }

                return true
            case .documentHasNoFileURL, .assetsPathIsNotDirectory:
                presentPasteImageError(error)
                return true
            }
        }

        private func insertImageMarkdown(_ markdown: String, into textView: NSTextView) {
            textView.undoManager?.beginUndoGrouping()
            textView.insertText(markdown, replacementRange: textView.selectedRange())
            textView.undoManager?.endUndoGrouping()
            text = textView.string
            applyHighlighting(to: textView, searchText: "")
        }

        private func shouldCompleteCodeFence(in source: String, at location: Int) -> Bool {
            let nsString = source as NSString
            guard location <= nsString.length,
                  location >= 2,
                  nsString.substring(with: NSRange(location: location - 2, length: 2)) == "``" else {
                return false
            }

            let lineRange = nsString.lineRange(for: NSRange(location: location, length: 0))
            let linePrefixRange = NSRange(location: lineRange.location, length: location - lineRange.location)
            let linePrefix = nsString.substring(with: linePrefixRange)
            return linePrefix.range(of: #"^\s*``$"#, options: .regularExpression) != nil
        }

        func apply(_ command: MarkdownEditCommand, to textView: NSTextView) {
            textView.undoManager?.beginUndoGrouping()
            defer {
                textView.undoManager?.endUndoGrouping()
                text = textView.string
            }

            switch command.kind {
            case let .heading(level):
                prefixSelectedLines(in: textView, prefix: String(repeating: "#", count: level) + " ", removing: #"^#{1,6}\s+"#)
            case .bold:
                wrapSelection(in: textView, prefix: "**", suffix: "**", placeholder: "bold")
            case .italic:
                wrapSelection(in: textView, prefix: "*", suffix: "*", placeholder: "italic")
            case .inlineCode:
                wrapSelection(in: textView, prefix: "`", suffix: "`", placeholder: "code")
            case .codeBlock:
                insertCodeBlock(into: textView)
            case .quote:
                prefixSelectedLines(in: textView, prefix: "> ")
            case .unorderedList:
                prefixSelectedLines(in: textView, prefix: "- ", removing: #"^([-*+]\s+|\d+\.\s+|- \[[ xX]\]\s+)"#)
            case .orderedList:
                numberSelectedLines(in: textView)
            case .taskList:
                prefixSelectedLines(in: textView, prefix: "- [ ] ", removing: #"^([-*+]\s+|\d+\.\s+|- \[[ xX]\]\s+)"#)
            case .link:
                wrapSelection(in: textView, prefix: "[", suffix: "](https://)", placeholder: "link")
            case .image:
                insertTemplate("![alt text](image-url)", into: textView)
            case .table:
                insertTemplate("\n| Column | Column |\n| --- | --- |\n| Value | Value |\n", into: textView)
            }
        }

        func applyHighlighting(to textView: NSTextView, searchText: String) {
            guard let storage = textView.textStorage else { return }

            isHighlighting = true
            let selectedRange = textView.selectedRange()
            let fullRange = NSRange(location: 0, length: storage.length)
            let visibleOrigin = textView.enclosingScrollView?.contentView.bounds.origin

            storage.beginEditing()
            storage.setAttributes(baseTypingAttributes, range: fullRange)
            highlightMarkdown(in: storage)
            highlightSearch(searchText, in: storage)
            storage.endEditing()

            textView.typingAttributes = baseTypingAttributes
            textView.setSelectedRange(validRange(selectedRange, in: fullRange) ? selectedRange : NSRange(location: storage.length, length: 0))
            restoreVisibleOrigin(visibleOrigin, in: textView)
            isHighlighting = false
        }

        private func wrapSelection(in textView: NSTextView, prefix: String, suffix: String, placeholder: String) {
            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let selectedText = selectedRange.length > 0 ? nsString.substring(with: selectedRange) : placeholder
            let replacement = "\(prefix)\(selectedText)\(suffix)"
            textView.insertText(replacement, replacementRange: selectedRange)

            if selectedRange.length == 0 {
                textView.setSelectedRange(NSRange(location: selectedRange.location + prefix.count, length: placeholder.count))
            }
        }

        private func insertTemplate(_ template: String, into textView: NSTextView) {
            let range = textView.selectedRange()
            textView.insertText(template, replacementRange: range)
            textView.setSelectedRange(NSRange(location: range.location + (template as NSString).length, length: 0))
        }

        private func insertCodeBlock(into textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let selectedText = selectedRange.length > 0 ? nsString.substring(with: selectedRange) : ""
            let body = selectedText.isEmpty ? "" : "\n\(selectedText)"
            let replacement = "```\(body)\n```"

            textView.insertText(replacement, replacementRange: selectedRange)
            textView.setSelectedRange(NSRange(location: selectedRange.location + 3, length: 0))
        }

        private func prefixSelectedLines(in textView: NSTextView, prefix: String, removing pattern: String? = nil) {
            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let lineRange = nsString.lineRange(for: selectedRange)
            let selectedLines = nsString.substring(with: lineRange)
            let lines = selectedLines.components(separatedBy: "\n")
            let hasTrailingNewline = selectedLines.hasSuffix("\n")
            let editableLines = hasTrailingNewline ? lines.dropLast() : ArraySlice(lines)

            let updated = editableLines.map { line in
                let cleaned = pattern.map { line.replacingOccurrences(of: $0, with: "", options: .regularExpression) } ?? line
                return cleaned.isEmpty ? prefix.trimmingCharacters(in: .whitespaces) : prefix + cleaned
            }
            .joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")

            textView.insertText(updated, replacementRange: lineRange)
            textView.setSelectedRange(NSRange(location: lineRange.location, length: (updated as NSString).length))
        }

        private func numberSelectedLines(in textView: NSTextView) {
            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let lineRange = nsString.lineRange(for: selectedRange)
            let selectedLines = nsString.substring(with: lineRange)
            let lines = selectedLines.components(separatedBy: "\n")
            let hasTrailingNewline = selectedLines.hasSuffix("\n")
            let editableLines = hasTrailingNewline ? lines.dropLast() : ArraySlice(lines)

            let updated = editableLines.enumerated().map { index, line in
                let cleaned = line.replacingOccurrences(of: #"^([-*+]\s+|\d+\.\s+|- \[[ xX]\]\s+)"#, with: "", options: .regularExpression)
                return "\(index + 1). \(cleaned)"
            }
            .joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")

            textView.insertText(updated, replacementRange: lineRange)
            textView.setSelectedRange(NSRange(location: lineRange.location, length: (updated as NSString).length))
        }

        private func highlightMarkdown(in storage: NSTextStorage) {
            let string = storage.string as NSString
            let fullRange = NSRange(location: 0, length: string.length)

            apply(pattern: #"(?m)^#{1,6}\s+.*$"#, in: storage, range: fullRange, color: .controlAccentColor, font: .systemFont(ofSize: 15, weight: .semibold))
            apply(pattern: #"(?m)^>\s+.*$"#, in: storage, range: fullRange, color: .secondaryLabelColor)
            apply(pattern: #"`[^`\n]+`"#, in: storage, range: fullRange, color: .systemPurple)
            apply(pattern: #"\*\*[^*\n]+\*\*"#, in: storage, range: fullRange, font: .monospacedSystemFont(ofSize: 15, weight: .semibold))
            apply(pattern: #"(?m)^(-|\*|\+|\d+\.|- \[[ xX]\])\s+"#, in: storage, range: fullRange, color: .systemBlue)
            apply(pattern: #"(?m)^```.*$"#, in: storage, range: fullRange, color: .systemPurple, font: .monospacedSystemFont(ofSize: 15, weight: .semibold))
            apply(pattern: #"!?\[[^\]]+\]\([^)]+\)"#, in: storage, range: fullRange, color: .systemBlue)
            apply(pattern: #"(?m)^\|.*\|$"#, in: storage, range: fullRange, color: .systemTeal)
        }

        private func highlightSearch(_ query: String, in storage: NSTextStorage) {
            guard !query.isEmpty else { return }

            let string = storage.string as NSString
            var searchRange = NSRange(location: 0, length: string.length)

            while true {
                let foundRange = string.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                guard foundRange.location != NSNotFound else { break }
                storage.addAttribute(.backgroundColor, value: NSColor.controlAccentColor.withAlphaComponent(0.22), range: foundRange)

                let nextLocation = foundRange.location + foundRange.length
                guard nextLocation < string.length else { break }
                searchRange = NSRange(location: nextLocation, length: string.length - nextLocation)
            }
        }

        private func apply(
            pattern: String,
            in storage: NSTextStorage,
            range: NSRange,
            color: NSColor? = nil,
            font: NSFont? = nil
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

            regex.enumerateMatches(in: storage.string, range: range) { match, _, _ in
                guard let match else { return }
                if let color {
                    storage.addAttribute(.foregroundColor, value: color, range: match.range)
                }
                if let font {
                    storage.addAttribute(.font, value: font, range: match.range)
                }
            }
        }

        private func validRange(_ range: NSRange, in fullRange: NSRange) -> Bool {
            range.location >= fullRange.location &&
                range.location <= fullRange.location + fullRange.length &&
                range.location + range.length <= fullRange.location + fullRange.length
        }

        private func restoreVisibleOrigin(_ origin: NSPoint?, in textView: NSTextView) {
            guard let origin,
                  let scrollView = textView.enclosingScrollView else {
                return
            }

            if let textContainer = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: textContainer)
            }

            let clipView = scrollView.contentView
            let documentHeight = textView.bounds.height
            let maxY = max(0, documentHeight - clipView.bounds.height)
            let restoredOrigin = NSPoint(x: origin.x, y: min(max(0, origin.y), maxY))

            clipView.scroll(to: restoredOrigin)
            scrollView.reflectScrolledClipView(clipView)
        }

        private func scrollRatio(for textView: NSTextView, in clipView: NSClipView) -> Double {
            if let textContainer = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: textContainer)
            }

            let maxY = max(0, textView.bounds.height - clipView.bounds.height)
            guard maxY > 0 else { return 0 }
            return Double(clipView.bounds.origin.y / maxY)
        }

        private func scroll(to ratio: Double, textView: NSTextView, in scrollView: NSScrollView) {
            if let textContainer = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: textContainer)
            }

            let clipView = scrollView.contentView
            let maxY = max(0, textView.bounds.height - clipView.bounds.height)
            let targetY = maxY * CGFloat(min(max(ratio, 0), 1))

            isApplyingSyncedScroll = true
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
            isApplyingSyncedScroll = false
        }
    }
}

private final class MarkdownTextView: NSTextView {
    var onPasteImage: ((NSTextView) -> Bool)?

    override func paste(_ sender: Any?) {
        if onPasteImage?(self) == true {
            return
        }

        super.paste(sender)
    }
}

private func presentPasteImageError(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "Could not paste image"
    alert.informativeText = error.localizedDescription
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

private func confirmCreateAssetsDirectory(_ url: URL) -> Bool {
    let alert = NSAlert()
    alert.messageText = "Create assets folder?"
    alert.informativeText = "Mira saves pasted images into:\n\(url.path)"
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Create")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
}
