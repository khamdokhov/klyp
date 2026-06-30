import AppKit
import Foundation

struct StoredRepresentations: Codable {
    var entries: [String: Data]
}

struct ClipStorage {
    private let itemsDirectory: URL

    init(itemsDirectory: URL = StoragePaths.itemsDirectory) {
        self.itemsDirectory = itemsDirectory
    }

    func saveBody(_ representations: [String: Data], for id: UUID) throws {
        try ensureItemsDirectory()
        let payload = StoredRepresentations(entries: representations)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: bodyFile(for: id), options: .atomic)
    }

    func loadBody(for id: UUID) throws -> [String: Data] {
        let url = bodyFile(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StorageError.missingBody(id)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StoredRepresentations.self, from: data).entries
    }

    func saveThumbnail(from representations: [String: Data], kind: ClipItemKind, for id: UUID) throws -> String? {
        guard kind == .image || kind == .file else { return nil }

        guard let image = imageFromRepresentations(representations) else {
            Log.error(
                "Thumbnail generation failed for clip \(id.uuidString.prefix(8)): "
                    + "no decodable image in types [\(representations.keys.sorted().joined(separator: ", "))]"
            )
            return nil
        }

        guard let data = ImageThumbnail.aspectFitPNG(from: image) else {
            Log.error(
                "Thumbnail generation failed for clip \(id.uuidString.prefix(8)): "
                    + "could not render aspect-fit PNG from \(Int(image.size.width))×\(Int(image.size.height)) image"
            )
            return nil
        }

        try ensureItemsDirectory()
        let url = thumbnailFile(for: id)
        try data.write(to: url, options: .atomic)

        guard FileManager.default.fileExists(atPath: url.path) else {
            Log.error("Thumbnail write verification failed for clip \(id.uuidString.prefix(8)) at \(url.path)")
            return nil
        }

        Log.info(
            "Saved thumbnail \(url.lastPathComponent) for clip \(id.uuidString.prefix(8)) "
                + "(\(data.count) bytes, \(Int(ImageThumbnail.pointSize * ImageThumbnail.scale))px)"
        )
        return url.lastPathComponent
    }

    func deleteItemFiles(for id: UUID) {
        try? FileManager.default.removeItem(at: bodyFile(for: id))
        try? FileManager.default.removeItem(at: thumbnailFile(for: id))
    }

    func totalBytesOnDisk() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: itemsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + size
        }
    }

    func thumbnailURL(for ref: String?) -> URL? {
        guard let ref else { return nil }
        return itemsDirectory.appendingPathComponent(ref)
    }

    private func ensureItemsDirectory() throws {
        try FileManager.default.createDirectory(at: itemsDirectory, withIntermediateDirectories: true)
    }

    private func bodyFile(for id: UUID) -> URL {
        itemsDirectory.appendingPathComponent("\(id.uuidString).dat")
    }

    private func thumbnailFile(for id: UUID) -> URL {
        itemsDirectory.appendingPathComponent("\(id.uuidString).thumb.png")
    }

    private func imageFromRepresentations(_ representations: [String: Data]) -> NSImage? {
        ImageThumbnail.imageFromRepresentations(representations)
    }
}
