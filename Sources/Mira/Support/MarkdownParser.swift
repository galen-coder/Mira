import Foundation

enum MarkdownParser {
    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if trimmed.isEmpty {
                blocks.append(MarkdownBlock(line: lineNumber, kind: .blank))
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).nilIfEmpty
                var codeLines: [String] = []
                index += 1

                while index < lines.count {
                    let codeLine = lines[index]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        break
                    }
                    codeLines.append(codeLine)
                    index += 1
                }

                blocks.append(MarkdownBlock(line: lineNumber, kind: .code(language: language, text: codeLines.joined(separator: "\n"))))
                index += 1
                continue
            }

            if let heading = parseHeading(trimmed) {
                blocks.append(MarkdownBlock(line: lineNumber, kind: .heading(level: heading.level, text: heading.text)))
                index += 1
                continue
            }

            if isDivider(trimmed) {
                blocks.append(MarkdownBlock(line: lineNumber, kind: .divider))
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard candidate.hasPrefix(">") else { break }
                    quoteLines.append(String(candidate.dropFirst()).trimmingCharacters(in: .whitespaces))
                    index += 1
                }
                blocks.append(MarkdownBlock(line: lineNumber, kind: .quote(quoteLines.joined(separator: "\n"))))
                continue
            }

            if isTaskList(trimmed) {
                var items: [TaskListItem] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let item = taskListItem(candidate) else { break }
                    items.append(item)
                    index += 1
                }
                blocks.append(MarkdownBlock(line: lineNumber, kind: .taskList(items)))
                continue
            }

            if let image = imageLine(trimmed) {
                blocks.append(MarkdownBlock(line: lineNumber, kind: .image(alt: image.alt, source: image.source)))
                index += 1
                continue
            }

            if let table = tableBlock(lines: lines, startingAt: index) {
                blocks.append(MarkdownBlock(line: lineNumber, kind: .table(headers: table.headers, rows: table.rows)))
                index = table.nextIndex
                continue
            }

            if containsHTMLTag(trimmed) {
                var htmlLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index]
                    guard !candidate.trimmingCharacters(in: .whitespaces).isEmpty else { break }
                    htmlLines.append(candidate)
                    index += 1
                }
                blocks.append(MarkdownBlock(line: lineNumber, kind: .html(htmlLines.joined(separator: "\n"))))
                continue
            }

            if isUnorderedList(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard isUnorderedList(candidate) else { break }
                    items.append(String(candidate.dropFirst(2)))
                    index += 1
                }
                blocks.append(MarkdownBlock(line: lineNumber, kind: .unorderedList(items)))
                continue
            }

            if isOrderedList(trimmed) {
                var items: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    guard let item = orderedListItem(candidate) else { break }
                    items.append(item)
                    index += 1
                }
                blocks.append(MarkdownBlock(line: lineNumber, kind: .orderedList(items)))
                continue
            }

            var paragraphLines = [line]
            index += 1

            while index < lines.count {
                let candidate = lines[index]
                let trimmedCandidate = candidate.trimmingCharacters(in: .whitespaces)
                if trimmedCandidate.isEmpty ||
                    trimmedCandidate.hasPrefix("```") ||
                    trimmedCandidate.hasPrefix(">") ||
                    parseHeading(trimmedCandidate) != nil ||
                    isTaskList(trimmedCandidate) ||
                    imageLine(trimmedCandidate) != nil ||
                    tableBlock(lines: lines, startingAt: index) != nil ||
                    containsHTMLTag(trimmedCandidate) ||
                    isUnorderedList(trimmedCandidate) ||
                    isOrderedList(trimmedCandidate) ||
                    isDivider(trimmedCandidate) {
                    break
                }
                paragraphLines.append(candidate)
                index += 1
            }

            blocks.append(MarkdownBlock(line: lineNumber, kind: .paragraph(paragraphLines.joined(separator: "\n"))))
        }

        return blocks
    }

    static func outline(from text: String) -> [OutlineItem] {
        parse(text).compactMap { block in
            guard case let .heading(level, title) = block.kind else { return nil }
            return OutlineItem(line: block.line, level: level, title: title)
        }
    }

    static func stats(for text: String) -> DocumentStats {
        let words = text
            .split { $0.isWhitespace || $0.isNewline }
            .count
        let characters = text.count
        let headings = text
            .components(separatedBy: .newlines)
            .filter { parseHeading($0.trimmingCharacters(in: .whitespaces)) != nil }
            .count
        let minutes = max(1, Int(ceil(Double(words) / 220.0)))

        return DocumentStats(words: words, characters: characters, headings: headings, readingMinutes: minutes)
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else { return nil }
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
        return (level, String(line.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces))
    }

    private static func isDivider(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        return stripped.count >= 3 && Set(stripped).isSubset(of: Set(["-", "*", "_"]))
    }

    private static func isUnorderedList(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func isTaskList(_ line: String) -> Bool {
        taskListItem(line) != nil
    }

    private static func taskListItem(_ line: String) -> TaskListItem? {
        let lower = line.lowercased()
        let prefixes = [("- [ ] ", false), ("- [x] ", true), ("* [ ] ", false), ("* [x] ", true), ("+ [ ] ", false), ("+ [x] ", true)]

        for (prefix, isComplete) in prefixes where lower.hasPrefix(prefix) {
            return TaskListItem(isComplete: isComplete, text: String(line.dropFirst(prefix.count)))
        }

        return nil
    }

    private static func imageLine(_ line: String) -> (alt: String, source: String)? {
        guard line.hasPrefix("!["), let closeAlt = line.firstIndex(of: "]") else { return nil }
        let openSource = line.index(after: closeAlt)
        guard openSource < line.endIndex, line[openSource] == "(" else { return nil }
        guard line.hasSuffix(")") else { return nil }

        let alt = String(line[line.index(line.startIndex, offsetBy: 2)..<closeAlt])
        let sourceStart = line.index(after: openSource)
        let sourceEnd = line.index(before: line.endIndex)
        return (alt, String(line[sourceStart..<sourceEnd]))
    }

    private static func tableBlock(lines: [String], startingAt index: Int) -> (headers: [String], rows: [[String]], nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }

        let headerLine = lines[index].trimmingCharacters(in: .whitespaces)
        let separatorLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard headerLine.contains("|"), isTableSeparator(separatorLine) else { return nil }

        let headers = tableCells(headerLine)
        guard !headers.isEmpty else { return nil }

        var rows: [[String]] = []
        var cursor = index + 2

        while cursor < lines.count {
            let rowLine = lines[cursor].trimmingCharacters(in: .whitespaces)
            guard rowLine.contains("|"), !rowLine.isEmpty else { break }
            rows.append(tableCells(rowLine))
            cursor += 1
        }

        return (headers, rows, cursor)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        guard line.contains("|") else { return false }
        return tableCells(line).allSatisfy { cell in
            let stripped = cell.replacingOccurrences(of: ":", with: "")
            return stripped.count >= 3 && stripped.allSatisfy { $0 == "-" }
        }
    }

    private static func tableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isOrderedList(_ line: String) -> Bool {
        orderedListItem(line) != nil
    }

    private static func containsHTMLTag(_ line: String) -> Bool {
        guard line.contains("<"), line.contains(">") else { return false }
        return line.range(of: htmlTagPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func orderedListItem(_ line: String) -> String? {
        guard let dot = line.firstIndex(of: ".") else { return nil }
        let number = line[..<dot]
        guard !number.isEmpty, number.allSatisfy(\.isNumber) else { return nil }
        let afterDot = line.index(after: dot)
        guard afterDot < line.endIndex, line[afterDot] == " " else { return nil }
        return String(line[line.index(after: afterDot)...])
    }

    private static let htmlTagPattern = #"<!--|<!doctype\s+html|</?(?:a|abbr|acronym|address|applet|article|aside|audio|b|base|basefont|bdi|bdo|big|blockquote|body|br|button|canvas|caption|center|cite|code|col|colgroup|data|datalist|dd|del|details|dfn|dialog|dir|div|dl|dt|em|embed|fieldset|figcaption|figure|font|footer|form|frame|frameset|h[1-6]|head|header|hr|html|i|iframe|img|input|ins|isindex|kbd|label|legend|li|link|main|map|mark|marquee|menu|meta|meter|nav|noframes|noscript|object|ol|optgroup|option|output|p|param|picture|pre|progress|q|rp|rt|ruby|s|samp|script|section|select|small|source|span|strike|strong|style|sub|summary|sup|svg|table|tbody|td|template|textarea|tfoot|th|thead|time|title|tr|track|tt|u|ul|var|video|wbr)(?:\s+[^>]*)?/?>"#
}

struct DocumentStats: Equatable {
    let words: Int
    let characters: Int
    let headings: Int
    let readingMinutes: Int
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
