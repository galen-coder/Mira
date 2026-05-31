import AppKit

enum RecentDocumentOpener {
    static func openRecentClosedDocument(showMissingAlert: Bool = true, allowPrivacyPrompt: Bool = true) {
        guard let url = RecentDocumentStore.availableRecentClosedDocumentURL else {
            RecentDocumentStore.recentClosedDocumentURL = nil
            if showMissingAlert {
                presentAlert(
                    titleKey: "recentDocument.missing.title",
                    messageKey: "recentDocument.missing.message"
                )
            }
            return
        }

        guard allowPrivacyPrompt || RecentDocumentStore.canOpenAutomaticallyWithoutPrivacyPrompt(url) else {
            return
        }

        openDocument(at: url, showErrorAlert: showMissingAlert)
    }

    private static func openDocument(at url: URL, showErrorAlert: Bool) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            [url],
            withApplicationAt: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            if error != nil {
                openDocumentThroughDocumentController(at: url, showErrorAlert: showErrorAlert)
            }
        }
    }

    private static func openDocumentThroughDocumentController(at url: URL, showErrorAlert: Bool) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if error != nil {
                RecentDocumentStore.recentClosedDocumentURL = nil
                if showErrorAlert {
                    presentAlert(
                        titleKey: "recentDocument.openFailed.title",
                        messageKey: "recentDocument.openFailed.message"
                    )
                }
            }
        }
    }

    private static func presentAlert(titleKey: String, messageKey: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = localized(titleKey)
            alert.informativeText = localized(messageKey)
            alert.addButton(withTitle: localized("alert.ok"))
            alert.runModal()
        }
    }

    private static func localized(_ key: String) -> String {
        let rawLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue
        let language = AppLanguage(rawValue: rawLanguage) ?? .system
        return L10n.tr(key, language: language)
    }
}
