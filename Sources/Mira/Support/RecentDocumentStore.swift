import Foundation

enum RecentDocumentStore {
    private static let recentClosedDocumentPathKey = "recentClosedDocumentPath"

    static var recentClosedDocumentURL: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: recentClosedDocumentPathKey),
                  !path.isEmpty else {
                return nil
            }

            return URL(fileURLWithPath: path)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.path, forKey: recentClosedDocumentPathKey)
            } else {
                UserDefaults.standard.removeObject(forKey: recentClosedDocumentPathKey)
            }
        }
    }

    static var availableRecentClosedDocumentURL: URL? {
        recentClosedDocumentURL
    }

    static func canOpenAutomaticallyWithoutPrivacyPrompt(_ url: URL) -> Bool {
        !isInsidePrivacyPromptedUserDirectory(url)
    }

    private static func isInsidePrivacyPromptedUserDirectory(_ url: URL) -> Bool {
        let protectedDirectories: [FileManager.SearchPathDirectory] = [
            .desktopDirectory,
            .documentDirectory,
            .downloadsDirectory
        ]

        let path = url.standardizedFileURL.path
        return protectedDirectories
            .compactMap { FileManager.default.urls(for: $0, in: .userDomainMask).first?.standardizedFileURL.path }
            .contains { protectedPath in
                path == protectedPath || path.hasPrefix(protectedPath + "/")
            }
    }
}
