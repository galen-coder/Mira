import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct WindowLifecycleView: NSViewRepresentable {
    let documentURL: URL?
    let isDocumentEmpty: Bool
    let documentText: String

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            WindowLifecycleCoordinator.shared.update(
                window: window,
                documentURL: documentURL,
                isDocumentEmpty: isDocumentEmpty,
                documentText: documentText
            )
        }
    }
}

private final class WindowLifecycleCoordinator {
    static let shared = WindowLifecycleCoordinator()

    private struct Record {
        weak var window: NSWindow?
        var documentURL: URL?
        var isDocumentEmpty: Bool
        var documentText: String
    }

    private var records: [ObjectIdentifier: Record] = [:]
    private var closeObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private var pendingTemporaryPrompts: Set<ObjectIdentifier> = []
    private var promptedTemporaryOpenMarkers: [ObjectIdentifier: Set<String>] = [:]
    private var didApplyInitialMaximizedFrame = false

    func update(window: NSWindow, documentURL: URL?, isDocumentEmpty: Bool, documentText: String) {
        let key = ObjectIdentifier(window)
        let previousRecord = records[key]
        if documentURL == nil, previousRecord?.documentText != nil, previousRecord?.documentText != documentText {
            promptedTemporaryOpenMarkers[key] = []
        }

        records[key] = Record(
            window: window,
            documentURL: documentURL,
            isDocumentEmpty: isDocumentEmpty,
            documentText: documentText
        )
        removeReleasedWindows()
        observeClose(for: window, key: key)

        applyInitialMaximizedFrameIfNeeded(to: window)

        if documentURL != nil {
            resolveUntitledWindowsAfterOpeningExistingFile(except: window)
        }
    }

    private func applyInitialMaximizedFrameIfNeeded(to window: NSWindow) {
        guard !didApplyInitialMaximizedFrame else { return }
        didApplyInitialMaximizedFrame = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let screen = window.screen ?? NSScreen.main,
                  !window.styleMask.contains(.fullScreen) else {
                return
            }

            window.setFrame(screen.visibleFrame, display: true, animate: true)
        }
    }

    private func resolveUntitledWindowsAfterOpeningExistingFile(except currentWindow: NSWindow) {
        let currentKey = ObjectIdentifier(currentWindow)
        guard let openedDocumentURL = records[currentKey]?.documentURL else { return }
        let openedDocumentMarker = openedDocumentURL.absoluteString

        for (key, record) in records {
            guard let window = record.window,
                  window !== currentWindow,
                  record.documentURL == nil else {
                continue
            }

            if record.isDocumentEmpty {
                closeWithoutSaving(window)
            } else if shouldPromptTemporaryWindow(key: key, openedDocumentMarker: openedDocumentMarker) {
                promptToSaveTemporaryDocument(window: window, key: key, text: record.documentText)
            }
        }
    }

    private func shouldPromptTemporaryWindow(key: ObjectIdentifier, openedDocumentMarker: String) -> Bool {
        guard !pendingTemporaryPrompts.contains(key),
              promptedTemporaryOpenMarkers[key]?.contains(openedDocumentMarker) != true else {
            return false
        }

        promptedTemporaryOpenMarkers[key, default: []].insert(openedDocumentMarker)
        return true
    }

    private func observeClose(for window: NSWindow, key: ObjectIdentifier) {
        guard closeObservers[key] == nil else { return }

        closeObservers[key] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.windowWillClose(key: key)
        }
    }

    private func windowWillClose(key: ObjectIdentifier) {
        if let documentURL = records[key]?.documentURL {
            RecentDocumentStore.recentClosedDocumentURL = documentURL
        }

        records.removeValue(forKey: key)
        pendingTemporaryPrompts.remove(key)
        promptedTemporaryOpenMarkers.removeValue(forKey: key)

        if let observer = closeObservers.removeValue(forKey: key) {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func removeReleasedWindows() {
        let releasedKeys = records.compactMap { key, record in
            record.window == nil ? key : nil
        }

        for key in releasedKeys {
            records.removeValue(forKey: key)
            pendingTemporaryPrompts.remove(key)
            promptedTemporaryOpenMarkers.removeValue(forKey: key)

            if let observer = closeObservers.removeValue(forKey: key) {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private func promptToSaveTemporaryDocument(window: NSWindow, key: ObjectIdentifier, text: String) {
        pendingTemporaryPrompts.insert(key)
        window.makeKeyAndOrderFront(nil)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localized("temporaryDocument.savePrompt.title")
        alert.informativeText = localized("temporaryDocument.savePrompt.message")
        alert.addButton(withTitle: localized("temporaryDocument.savePrompt.save"))
        alert.addButton(withTitle: localized("temporaryDocument.savePrompt.discard"))
        alert.addButton(withTitle: localized("temporaryDocument.savePrompt.cancel"))

        alert.beginSheetModal(for: window) { [weak self, weak window] response in
            guard let self, let window else { return }
            self.pendingTemporaryPrompts.remove(key)

            switch response {
            case .alertFirstButtonReturn:
                self.presentSavePanel(for: window, text: text)
            case .alertSecondButtonReturn:
                self.closeWithoutSaving(window)
            default:
                break
            }
        }
    }

    private func presentSavePanel(for window: NSWindow, text: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdown]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Untitled.md"

        panel.beginSheetModal(for: window) { [weak self, weak window] response in
            guard let self, let window else { return }
            guard response == .OK, let url = panel.url else { return }

            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                RecentDocumentStore.recentClosedDocumentURL = url
                self.closeWithoutSaving(window)
            } catch {
                self.presentSaveError(error, for: window)
            }
        }
    }

    private func closeWithoutSaving(_ window: NSWindow) {
        if let document = window.windowController?.document as? NSDocument {
            document.updateChangeCount(.changeCleared)
        }

        window.close()
    }

    private func presentSaveError(_ error: Error, for window: NSWindow) {
        let alert = NSAlert(error: error)
        alert.beginSheetModal(for: window)
    }

    private func localized(_ key: String) -> String {
        let rawLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        let language = AppLanguage(rawValue: rawLanguage) ?? .system
        return L10n.tr(key, language: language)
    }

    deinit {
        for observer in closeObservers.values {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
