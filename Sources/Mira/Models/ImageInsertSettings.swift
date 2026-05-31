import Foundation

enum ImageInsertAction: String, CaseIterable, Identifiable {
    case copyToAssets
    case linkOriginal

    var id: String { rawValue }
}

enum AssetsFolderBehavior: String, CaseIterable, Identifiable {
    case ask
    case createAutomatically

    var id: String { rawValue }
}
