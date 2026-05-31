import AppKit
import Foundation

enum ClipboardImageAssetWriter {
    enum WriteError: LocalizedError {
        case documentHasNoFileURL
        case assetsDirectoryMissing(URL)
        case assetsPathIsNotDirectory(URL)

        var errorDescription: String? {
            switch self {
            case .documentHasNoFileURL:
                "Save the Markdown document before pasting images."
            case let .assetsDirectoryMissing(url):
                "The assets folder does not exist: \(url.path)"
            case let .assetsPathIsNotDirectory(url):
                "The assets path exists but is not a folder: \(url.path)"
            }
        }
    }

    static func markdownImageFromPasteboard(
        _ pasteboard: NSPasteboard,
        documentURL: URL?,
        createAssetsDirectory: Bool = false,
        insertAction: ImageInsertAction = .copyToAssets,
        assetsFolderName: String = "assets"
    ) throws -> String? {
        guard let asset = imageAsset(from: pasteboard) else {
            return nil
        }

        if insertAction == .linkOriginal, case let .file(sourceURL) = asset {
            return markdown(for: sourceURL, documentURL: documentURL)
        }

        guard let documentURL else {
            throw WriteError.documentHasNoFileURL
        }

        let documentDirectory = documentURL.deletingLastPathComponent()
        let folderName = sanitizedFolderName(assetsFolderName)
        let assetsDirectory = documentDirectory.appendingPathComponent(folderName, isDirectory: true)
        try prepareAssetsDirectory(assetsDirectory, createIfMissing: createAssetsDirectory)

        let filename = uniqueFilename(for: asset.preferredFilename, in: assetsDirectory)
        let destination = assetsDirectory.appendingPathComponent(filename)
        try asset.write(to: destination)

        return "![\(filenameWithoutExtension(filename))](\(folderName)/\(filename))"
    }

    private static func prepareAssetsDirectory(_ directory: URL, createIfMissing: Bool) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory)

        if exists {
            guard isDirectory.boolValue else {
                throw WriteError.assetsPathIsNotDirectory(directory)
            }
            return
        }

        guard createIfMissing else {
            throw WriteError.assetsDirectoryMissing(directory)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func imageAsset(from pasteboard: NSPasteboard) -> ClipboardImageAsset? {
        if let fileURL = imageFileURL(from: pasteboard) {
            return .file(fileURL)
        }

        for imageType in imageDataTypes {
            if let data = pasteboard.data(forType: imageType.pasteboardType),
               NSImage(data: data) != nil {
                return .data(data, preferredFilename: "image-\(timestamp()).\(imageType.fileExtension)")
            }
        }

        if let data = pasteboard.data(forType: .png), NSImage(data: data) != nil {
            return .data(data, preferredFilename: "image-\(timestamp()).png")
        }

        if let data = pasteboard.data(forType: .tiff),
           let bitmap = NSBitmapImageRep(data: data),
           let png = bitmap.representation(using: .png, properties: [:]) {
            return .data(png, preferredFilename: "image-\(timestamp()).png")
        }

        if let image = NSImage(pasteboard: pasteboard),
           let png = image.pngData {
            return .data(png, preferredFilename: "image-\(timestamp()).png")
        }

        return nil
    }

    private static let imageDataTypes: [(pasteboardType: NSPasteboard.PasteboardType, fileExtension: String)] = [
        (NSPasteboard.PasteboardType("public.jpeg"), "jpg"),
        (NSPasteboard.PasteboardType("public.jpg"), "jpg"),
        (NSPasteboard.PasteboardType("public.heic"), "heic"),
        (NSPasteboard.PasteboardType("public.heif"), "heif"),
        (NSPasteboard.PasteboardType("org.webmproject.webp"), "webp")
    ]

    private static func imageFileURL(from pasteboard: NSPasteboard) -> URL? {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]

        if let url = urls?.first(where: isSupportedImageFile) {
            return url
        }

        if let value = pasteboard.string(forType: .fileURL),
           let url = URL(string: value),
           isSupportedImageFile(url) {
            return url
        }

        return nil
    }

    private static func isSupportedImageFile(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        return ["png", "jpg", "jpeg", "gif", "heic", "tif", "tiff", "webp"].contains(url.pathExtension.lowercased())
    }

    private static func uniqueFilename(for preferredFilename: String, in directory: URL) -> String {
        let sanitized = sanitizedFilename(preferredFilename)
        let url = URL(fileURLWithPath: sanitized)
        let base = url.deletingPathExtension().lastPathComponent.nilIfEmpty ?? "image-\(timestamp())"
        let ext = url.pathExtension.nilIfEmpty ?? "png"
        var candidate = "\(base).\(ext)"
        var index = 1

        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(base)-\(index).\(ext)"
            index += 1
        }

        return candidate
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "image-\(timestamp()).png" : trimmed
        let disallowed = CharacterSet(charactersIn: "/:\\")
        return fallback.components(separatedBy: disallowed).joined(separator: "-")
    }

    private static func sanitizedFolderName(_ folderName: String) -> String {
        let trimmed = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "assets" : trimmed
        let disallowed = CharacterSet(charactersIn: "/:\\")
        return fallback.components(separatedBy: disallowed).joined(separator: "-")
    }

    private static func markdown(for sourceURL: URL, documentURL: URL?) -> String {
        let path = markdownPath(for: sourceURL, documentURL: documentURL)
        return "![\(filenameWithoutExtension(sourceURL.lastPathComponent))](\(wrappedIfNeeded(path)))"
    }

    private static func markdownPath(for sourceURL: URL, documentURL: URL?) -> String {
        guard let documentURL else {
            return sourceURL.path
        }

        let documentDirectory = documentURL.deletingLastPathComponent().standardizedFileURL.path
        let sourcePath = sourceURL.standardizedFileURL.path
        guard sourcePath.hasPrefix(documentDirectory + "/") else {
            return sourcePath
        }

        return String(sourcePath.dropFirst(documentDirectory.count + 1))
    }

    private static func wrappedIfNeeded(_ path: String) -> String {
        path.rangeOfCharacter(from: .whitespacesAndNewlines) == nil ? path : "<\(path)>"
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func filenameWithoutExtension(_ filename: String) -> String {
        URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    }
}

private enum ClipboardImageAsset {
    case data(Data, preferredFilename: String)
    case file(URL)

    var preferredFilename: String {
        switch self {
        case let .data(_, preferredFilename):
            preferredFilename
        case let .file(url):
            url.lastPathComponent
        }
    }

    func write(to destination: URL) throws {
        switch self {
        case let .data(data, _):
            try data.write(to: destination, options: .atomic)
        case let .file(source):
            try FileManager.default.copyItem(at: source, to: destination)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
