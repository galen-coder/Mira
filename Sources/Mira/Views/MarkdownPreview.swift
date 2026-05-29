import AppKit
import SwiftUI

struct MarkdownPreview: View {
    let text: String
    let searchText: String
    let fontSize: Double
    let isFocusMode: Bool

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(text)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block, searchText: searchText, fontSize: fontSize)
                }
            }
            .frame(maxWidth: isFocusMode ? 760 : 900, alignment: .leading)
            .padding(.horizontal, isFocusMode ? 72 : 36)
            .padding(.top, 32)
            .padding(.bottom, 56)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let searchText: String
    let fontSize: Double

    var body: some View {
        switch block.kind {
        case let .heading(level, text):
            heading(text, level: level)
        case let .paragraph(text):
            MarkdownText.inline(text)
                .font(.system(size: fontSize))
                .lineSpacing(5)
                .textSelection(.enabled)
        case let .quote(text):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(.tertiary)
                    .frame(width: 3)
                MarkdownText.inline(text)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 4)
        case let .unorderedList(items):
            list(items: items, ordered: false)
        case let .orderedList(items):
            list(items: items, ordered: true)
        case let .taskList(items):
            TaskListPreview(items: items, fontSize: fontSize)
        case let .table(headers, rows):
            MarkdownTable(headers: headers, rows: rows, fontSize: fontSize)
        case let .image(alt, source):
            ImagePreview(alt: alt, source: source, fontSize: fontSize)
        case let .code(language, text):
            CodeBlock(language: language, text: text)
        case .divider:
            Divider()
                .padding(.vertical, 10)
        case .blank:
            Color.clear
                .frame(height: 2)
        }
    }

    private func heading(_ text: String, level: Int) -> some View {
        MarkdownText.inline(text)
            .font(.system(size: headingSize(level), weight: headingWeight(level), design: .serif))
            .padding(.top, level <= 2 ? 18 : 8)
            .padding(.bottom, level <= 2 ? 4 : 0)
            .textSelection(.enabled)
    }

    private func headingSize(_ level: Int) -> Double {
        switch level {
        case 1:
            fontSize + 18
        case 2:
            fontSize + 10
        case 3:
            fontSize + 6
        default:
            fontSize + 2
        }
    }

    private func headingWeight(_ level: Int) -> Font.Weight {
        level <= 2 ? .bold : .semibold
    }

    private func list(items: [String], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .font(.system(size: fontSize))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)

                    MarkdownText.inline(item)
                        .font(.system(size: fontSize))
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct CodeBlock: View {
    let language: String?
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let language {
                Text(language.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(1)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct TaskListPreview: View {
    let items: [TaskListItem]
    let fontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: item.isComplete ? "checkmark.square.fill" : "square")
                        .foregroundStyle(item.isComplete ? .green : .secondary)
                        .frame(width: 20)

                    MarkdownText.inline(item.text)
                        .font(.system(size: fontSize))
                        .foregroundStyle(item.isComplete ? .secondary : .primary)
                        .strikethrough(item.isComplete)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct MarkdownTable: View {
    let headers: [String]
    let rows: [[String]]
    let fontSize: Double

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                    cell(header, isHeader: true)
                }
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(0..<headers.count, id: \.self) { index in
                        cell(index < row.count ? row[index] : "", isHeader: false)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(.quaternary)
        }
    }

    private func cell(_ text: String, isHeader: Bool) -> some View {
        MarkdownText.inline(text)
            .font(.system(size: fontSize, weight: isHeader ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 120, alignment: .leading)
            .background(isHeader ? Color(nsColor: .separatorColor).opacity(0.18) : Color.clear)
            .border(.quaternary, width: 0.5)
            .textSelection(.enabled)
    }
}

private struct ImagePreview: View {
    let alt: String
    let source: String
    let fontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = nsImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                    Text(alt.isEmpty ? source : alt)
                        .font(.system(size: fontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 7))
            }
        }
    }

    private var nsImage: NSImage? {
        if source.hasPrefix("http://") || source.hasPrefix("https://") {
            return nil
        }

        let expanded = NSString(string: source).expandingTildeInPath
        return NSImage(contentsOfFile: expanded)
    }
}
