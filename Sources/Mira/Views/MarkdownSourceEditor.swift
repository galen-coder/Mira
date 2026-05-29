import AppKit
import SwiftUI

struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var command: MarkdownEditCommand?

    let isFocusMode: Bool
    let searchText: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, command: $command)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
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
        context.coordinator.applyHighlighting(to: textView, searchText: searchText)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

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
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        @Binding private var command: MarkdownEditCommand?

        var lastCommandID: UUID?
        private var isHighlighting = false

        init(text: Binding<String>, command: Binding<MarkdownEditCommand?>) {
            _text = text
            _command = command
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

        func textDidChange(_ notification: Notification) {
            guard !isHighlighting, let textView = notification.object as? NSTextView else { return }
            text = textView.string
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
                wrapSelection(in: textView, prefix: "```\n", suffix: "\n```", placeholder: "code")
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

            storage.beginEditing()
            storage.setAttributes(baseTypingAttributes, range: fullRange)
            highlightMarkdown(in: storage)
            highlightSearch(searchText, in: storage)
            storage.endEditing()

            textView.typingAttributes = baseTypingAttributes
            textView.setSelectedRange(NSIntersectionRange(selectedRange, fullRange).length == selectedRange.length ? selectedRange : NSRange(location: storage.length, length: 0))
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
    }
}
