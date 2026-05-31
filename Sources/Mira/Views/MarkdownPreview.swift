import AppKit
import SwiftUI
import WebKit

struct MarkdownPreview: View {
    let text: String
    let documentURL: URL?
    let searchText: String
    let fontSize: Double
    let isFocusMode: Bool
    @ObservedObject var scrollSync: ScrollSyncState

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(text)
    }

    var body: some View {
        SynchronizedPreviewScrollView(scrollSync: scrollSync) {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block, documentURL: documentURL, searchText: searchText, fontSize: fontSize)
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
    let documentURL: URL?
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
            ImagePreview(alt: alt, source: source, documentURL: documentURL, fontSize: fontSize)
        case let .html(html):
            HTMLPreviewBlock(html: html, documentURL: documentURL, fontSize: fontSize)
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

private struct SynchronizedPreviewScrollView<Content: View>: NSViewRepresentable {
    @ObservedObject var scrollSync: ScrollSyncState
    let content: Content

    init(scrollSync: ScrollSyncState, @ViewBuilder content: () -> Content) {
        self.scrollSync = scrollSync
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scrollSync: scrollSync)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder
        scrollView.contentView.postsBoundsChangedNotifications = true

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width]
        hostingView.frame = NSRect(origin: .zero, size: scrollView.contentSize)
        scrollView.documentView = hostingView

        context.coordinator.configure(scrollView)
        context.coordinator.resizeDocument(in: scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let hostingView = scrollView.documentView as? NSHostingView<Content> else { return }
        hostingView.rootView = content
        context.coordinator.resizeDocument(in: scrollView)
        context.coordinator.applySyncedScrollIfNeeded(to: scrollView)
    }

    final class Coordinator: NSObject {
        private let scrollSync: ScrollSyncState
        private var isApplyingSyncedScroll = false
        private var lastAppliedScrollRevision = -1

        init(scrollSync: ScrollSyncState) {
            self.scrollSync = scrollSync
        }

        func configure(_ scrollView: NSScrollView) {
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
                  let documentView = clipView.documentView else {
                return
            }

            scrollSync.update(from: .preview, ratio: scrollRatio(for: documentView, in: clipView))
        }

        func resizeDocument(in scrollView: NSScrollView) {
            guard let hostingView = scrollView.documentView else { return }

            let width = max(scrollView.contentSize.width, 1)
            hostingView.frame.size.width = width
            let height = max(hostingView.fittingSize.height, scrollView.contentSize.height)
            hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        }

        func applySyncedScrollIfNeeded(to scrollView: NSScrollView) {
            guard scrollSync.source == .editor,
                  scrollSync.revision != lastAppliedScrollRevision,
                  let documentView = scrollView.documentView else {
                return
            }

            lastAppliedScrollRevision = scrollSync.revision
            scroll(to: scrollSync.ratio, documentView: documentView, in: scrollView)
        }

        private func scrollRatio(for documentView: NSView, in clipView: NSClipView) -> Double {
            let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
            guard maxY > 0 else { return 0 }
            return Double(clipView.bounds.origin.y / maxY)
        }

        private func scroll(to ratio: Double, documentView: NSView, in scrollView: NSScrollView) {
            let clipView = scrollView.contentView
            let maxY = max(0, documentView.bounds.height - clipView.bounds.height)
            let targetY = maxY * CGFloat(min(max(ratio, 0), 1))

            isApplyingSyncedScroll = true
            clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: targetY))
            scrollView.reflectScrolledClipView(clipView)
            isApplyingSyncedScroll = false
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

private struct HTMLPreviewBlock: View {
    let html: String
    let documentURL: URL?
    let fontSize: Double
    @State private var contentHeight: CGFloat = 44

    var body: some View {
        HTMLBlockView(html: html, documentURL: documentURL, fontSize: fontSize, contentHeight: $contentHeight)
            .frame(height: contentHeight)
    }
}

private struct HTMLBlockView: NSViewRepresentable {
    let html: String
    let documentURL: URL?
    let fontSize: Double
    @Binding var contentHeight: CGFloat

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.contentHeight = $contentHeight
        let renderKey = "\(fontSize)|\(documentURL?.absoluteString ?? "")|\(html)"
        guard context.coordinator.lastRenderKey != renderKey else { return }
        context.coordinator.lastRenderKey = renderKey
        webView.loadHTMLString(wrappedHTML, baseURL: documentURL?.deletingLastPathComponent())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    private var wrappedHTML: String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            html, body { width: 100%; min-height: 1px; }
            body {
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              font-size: \(fontSize)px;
              line-height: 1.55;
              color: CanvasText;
              background: transparent;
              margin: 0;
              overflow: hidden;
            }
            h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 0.8em 0 0.35em; }
            p { margin: 0.45em 0; }
            a { color: LinkText; }
            img { max-width: 100%; height: auto; }
            blockquote { border-left: 3px solid color-mix(in srgb, CanvasText 25%, transparent); margin: 0.6em 0; padding-left: 1em; color: color-mix(in srgb, CanvasText 72%, transparent); }
            pre { overflow-x: auto; padding: 12px; border-radius: 7px; background: color-mix(in srgb, CanvasText 8%, transparent); }
            code, kbd, pre { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
            table { border-collapse: collapse; }
            th, td { border: 1px solid color-mix(in srgb, CanvasText 20%, transparent); padding: 6px 10px; }
          </style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var contentHeight: Binding<CGFloat>
        var lastRenderKey = ""

        init(contentHeight: Binding<CGFloat>) {
            self.contentHeight = contentHeight
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measureHeight(in: webView)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.measureHeight(in: webView)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.measureHeight(in: webView)
            }
        }

        private func measureHeight(in webView: WKWebView) {
            webView.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight, document.body.offsetHeight)") { [weak self] value, _ in
                guard let self else { return }
                let measuredHeight: CGFloat

                if let number = value as? NSNumber {
                    measuredHeight = CGFloat(truncating: number)
                } else if let value = value as? CGFloat {
                    measuredHeight = value
                } else {
                    measuredHeight = 44
                }

                DispatchQueue.main.async {
                    self.contentHeight.wrappedValue = max(24, measuredHeight.rounded(.up) + 2)
                }
            }
        }
    }
}

private struct ImagePreview: View {
    let alt: String
    let source: String
    let documentURL: URL?
    let fontSize: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch imageSource {
            case let .remote(remoteURL):
                RemoteImageView(url: remoteURL, failurePlaceholder: {
                    placeholder(message: "Could not load remote image")
                })
            case let .local(fileURL):
                LocalImageView(url: fileURL) {
                    placeholder(message: fileURL.path)
                }
            case let .missing(message):
                placeholder(message: message)
            }
        }
    }

    private var imageSource: MarkdownImageSource {
        MarkdownImageSource(source: cleanedSource, documentURL: documentURL)
    }

    private var cleanedSource: String {
        var value = source.trimmingCharacters(in: .whitespacesAndNewlines)

        if value.hasPrefix("<"), value.hasSuffix(">"), value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }

        return value
    }

    private func placeholder(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(alt.isEmpty ? cleanedSource : alt)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 7))
    }
}

private enum MarkdownImageSource {
    case remote(URL)
    case local(URL)
    case missing(String)

    init(source: String, documentURL: URL?) {
        if let remoteURL = URL(string: source),
           let scheme = remoteURL.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            self = .remote(remoteURL)
            return
        }

        if let fileURL = URL(string: source), fileURL.isFileURL {
            self = .local(fileURL.standardizedFileURL)
            return
        }

        let decodedSource = source.removingPercentEncoding ?? source
        let expandedPath = NSString(string: decodedSource).expandingTildeInPath

        if expandedPath.hasPrefix("/") {
            self = .local(URL(fileURLWithPath: expandedPath).standardizedFileURL)
            return
        }

        guard let documentURL else {
            self = .missing("Save the document to preview relative image: \(source)")
            return
        }

        let baseDirectory = documentURL.deletingLastPathComponent()
        self = .local(URL(fileURLWithPath: expandedPath, relativeTo: baseDirectory).standardizedFileURL)
    }
}

private struct LocalImageView<FailurePlaceholder: View>: View {
    @StateObject private var loader: LocalImageLoader
    let failurePlaceholder: () -> FailurePlaceholder

    init(url: URL, @ViewBuilder failurePlaceholder: @escaping () -> FailurePlaceholder) {
        _loader = StateObject(wrappedValue: LocalImageLoader(url: url))
        self.failurePlaceholder = failurePlaceholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else if loader.didFail {
                failurePlaceholder()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .task {
            await loader.load()
        }
    }
}

@MainActor
private final class LocalImageLoader: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var didFail = false

    private static let cache = NSCache<NSURL, NSImage>()
    private static var failedURLs: Set<URL> = []
    private let url: URL
    private var hasLoaded = false

    init(url: URL) {
        self.url = url
        image = Self.cache.object(forKey: url as NSURL)
        didFail = Self.failedURLs.contains(url)
    }

    func load() async {
        guard image == nil, !didFail, !hasLoaded else { return }
        hasLoaded = true

        if let loadedImage = NSImage(contentsOf: url) {
            Self.cache.setObject(loadedImage, forKey: url as NSURL)
            image = loadedImage
        } else {
            Self.failedURLs.insert(url)
            didFail = true
        }
    }
}

private struct RemoteImageView<FailurePlaceholder: View>: View {
    @StateObject private var loader: RemoteImageLoader
    let failurePlaceholder: () -> FailurePlaceholder

    init(url: URL, @ViewBuilder failurePlaceholder: @escaping () -> FailurePlaceholder) {
        _loader = StateObject(wrappedValue: RemoteImageLoader(url: url))
        self.failurePlaceholder = failurePlaceholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else if loader.didFail {
                failurePlaceholder()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .task {
            await loader.load()
        }
    }
}

@MainActor
private final class RemoteImageLoader: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var didFail = false

    private static let cache = NSCache<NSURL, NSImage>()
    private let url: URL
    private var hasLoaded = false

    init(url: URL) {
        self.url = url
        image = Self.cache.object(forKey: url as NSURL)
    }

    func load() async {
        guard image == nil, !hasLoaded else { return }
        hasLoaded = true

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data) else {
                didFail = true
                return
            }

            Self.cache.setObject(image, forKey: url as NSURL)
            self.image = image
        } catch {
            didFail = true
        }
    }
}
