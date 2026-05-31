import Foundation

enum StartupDocumentBehavior: String, CaseIterable, Identifiable {
    case temporaryDocument
    case recentClosedDocument

    var id: String { rawValue }
}
