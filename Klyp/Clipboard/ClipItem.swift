import AppKit
import CryptoKit
import Foundation

struct SourceApp: Codable, Equatable, Hashable {
    var name: String
    var bundleIdentifier: String
}

struct ClipItem: Identifiable, Equatable, Hashable {
    var id: UUID
    var createdAt: Date
    var kind: ClipItemKind
    var representations: [String: Data]
    var previewText: String?
    var thumbnailRef: String?
    var source: SourceApp?
    var isPinned: Bool
    var isSecure: Bool
    var byteSize: Int

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: ClipItemKind,
        representations: [String: Data] = [:],
        previewText: String? = nil,
        thumbnailRef: String? = nil,
        source: SourceApp? = nil,
        isPinned: Bool = false,
        isSecure: Bool = false,
        byteSize: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.representations = representations
        self.previewText = previewText
        self.thumbnailRef = thumbnailRef
        self.source = source
        self.isPinned = isPinned
        self.isSecure = isSecure
        self.byteSize = byteSize
    }
}

extension ClipItem {
    var contentHash: String {
        switch kind {
        case .text, .richText, .link:
            return previewText ?? ""
        case .color, .image, .file:
            let payload = representations.values.max(by: { $0.count < $1.count }) ?? Data()
            return payload.sha256Hex
        }
    }
}

private extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}
