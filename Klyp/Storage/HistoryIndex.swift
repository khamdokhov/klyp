import Foundation

struct ClipItemRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var createdAt: Date
    var kind: ClipItemKind
    var previewText: String?
    var thumbnailRef: String?
    var source: SourceApp?
    var isPinned: Bool
    var isSecure: Bool
    var byteSize: Int
    var contentHash: String

    init(from item: ClipItem, contentHash overrideHash: String? = nil) {
        id = item.id
        createdAt = item.createdAt
        kind = item.kind
        previewText = item.previewText
        thumbnailRef = item.thumbnailRef
        source = item.source
        isPinned = item.isPinned
        isSecure = item.isSecure
        byteSize = item.byteSize
        contentHash = overrideHash ?? item.contentHash
    }

    func toClipItem(representations: [String: Data] = [:]) -> ClipItem {
        ClipItem(
            id: id,
            createdAt: createdAt,
            kind: kind,
            representations: representations,
            previewText: previewText,
            thumbnailRef: thumbnailRef,
            source: source,
            isPinned: isPinned,
            isSecure: isSecure,
            byteSize: byteSize
        )
    }
}

struct HistoryIndexFile: Codable {
    var records: [ClipItemRecord]
}

struct HistoryIndex {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL = StoragePaths.indexFile) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> [ClipItemRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(HistoryIndexFile.self, from: data).records
    }

    func save(_ records: [ClipItemRecord]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload = HistoryIndexFile(records: records)
        let data = try encoder.encode(payload)
        try data.write(to: fileURL, options: .atomic)
    }
}

enum StoragePaths {
    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Klyp", isDirectory: true)
    }

    static var indexFile: URL {
        appSupportDirectory.appendingPathComponent("index.json")
    }

    static var itemsDirectory: URL {
        appSupportDirectory.appendingPathComponent("items", isDirectory: true)
    }

    static func bodyFile(for id: UUID) -> URL {
        itemsDirectory.appendingPathComponent("\(id.uuidString).dat")
    }

    static func thumbnailFile(for id: UUID) -> URL {
        itemsDirectory.appendingPathComponent("\(id.uuidString).thumb.png")
    }
}

enum StorageError: Error {
    case missingBody(UUID)
    case writeFailed(String)
}
