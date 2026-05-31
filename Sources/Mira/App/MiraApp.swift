import AppKit
import SwiftUI

@main
struct MiraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, documentURL: file.fileURL)
                .frame(minWidth: 920, minHeight: 620)
        }
        .commands {
            MarkdownCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openStartupDocumentIfNeeded()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    private var startupBehavior: StartupDocumentBehavior {
        let rawValue = UserDefaults.standard.string(forKey: "startupDocumentBehavior")
        return StartupDocumentBehavior(rawValue: rawValue ?? "") ?? .temporaryDocument
    }

    private func openStartupDocumentIfNeeded() {
        guard startupBehavior == .recentClosedDocument else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            RecentDocumentOpener.openRecentClosedDocument(showMissingAlert: false, allowPrivacyPrompt: false)
        }
    }
}
