import AppKit
import Foundation

enum BackgroundImageStore {
    private static let directoryName = "Backgrounds"

    static var directoryURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return applicationSupport
            .appendingPathComponent("Moss", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    static func imageURL(fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        let url = directoryURL.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func image(fileName: String) -> NSImage? {
        guard let url = imageURL(fileName: fileName) else { return nil }
        return NSImage(contentsOf: url)
    }

    static func importImage(from sourceURL: URL) throws -> String {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: sourceURL)
        guard NSImage(data: data) != nil else {
            throw BackgroundImageError.invalidImage
        }

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let pathExtension = sourceURL.pathExtension.isEmpty
            ? "image"
            : sourceURL.pathExtension.lowercased()
        let fileName = "background-\(UUID().uuidString).\(pathExtension)"
        let destinationURL = directoryURL.appendingPathComponent(fileName)
        try data.write(to: destinationURL, options: .atomic)
        return fileName
    }

    static func removeImage(fileName: String) {
        guard let url = imageURL(fileName: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

enum BackgroundImageError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "所选文件不是 Moss 可以读取的图片。"
        }
    }
}
