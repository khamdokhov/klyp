import Foundation
import Observation

@MainActor
protocol HistoryStoring: AnyObject {
    var items: [ClipItem] { get set }
    func add(_ item: ClipItem) -> HistoryAddResult
    func remove(id: UUID)
    func clearAll()
    func setPinned(id: UUID, pinned: Bool)
    func loadRepresentations(for id: UUID) -> [String: Data]?
    func applyEvictionLimits()
}

enum HistoryAddResult: Equatable {
    case inserted
    case deduplicated(existingID: UUID)
    case failed
}

@MainActor
@Observable
final class HistoryStore: HistoryStoring {
    var items: [ClipItem] = []
    var onEvicted: ((Int) -> Void)?
    var onPinChanged: ((Bool) -> Void)?

    private var records: [ClipItemRecord] = []
    private let index: HistoryIndex
    private let clipStorage: ClipStorage
    private let secureStore: SecureStore
    private let settings: AppSettings

    init(
        index: HistoryIndex = HistoryIndex(),
        clipStorage: ClipStorage = ClipStorage(),
        secureStore: SecureStore = SecureStore(),
        settings: AppSettings
    ) {
        self.index = index
        self.clipStorage = clipStorage
        self.secureStore = secureStore
        self.settings = settings
        loadFromDisk()
    }

    func add(_ item: ClipItem) -> HistoryAddResult {
        if let existingIndex = records.firstIndex(where: { $0.contentHash == item.contentHash && !$0.isSecure }) {
            var record = records.remove(at: existingIndex)
            record.createdAt = Date()
            records.insert(record, at: 0)
            syncItemsFromRecords()
            persistIndex()
            Log.info("Deduplicated clip \(record.id.uuidString.prefix(8))")
            return .deduplicated(existingID: record.id)
        }

        var storedItem = item
        let contentHash = item.contentHash
        do {
            if storedItem.isSecure {
                try secureStore.save(item.representations, for: item.id)
                storedItem.representations = [:]
            } else {
                try clipStorage.saveBody(item.representations, for: item.id)
                if storedItem.thumbnailRef == nil {
                    storedItem.thumbnailRef = try clipStorage.saveThumbnail(
                        from: item.representations,
                        kind: item.kind,
                        for: item.id
                    )
                }
            }
        } catch {
            Log.error("Failed to persist clip body: \(error.localizedDescription)")
            return .failed
        }

        let record = ClipItemRecord(from: storedItem, contentHash: contentHash)
        records.insert(record, at: 0)
        syncItemsFromRecords()
        runEviction()
        persistIndex()

        let label = storedItem.isSecure ? "secure clip" : (item.previewText ?? item.kind.rawValue)
        Log.info("Captured \(storedItem.isSecure ? "secure " : "")clip \(item.id.uuidString.prefix(8)): \(label)")
        return .inserted
    }

    func remove(id: UUID) {
        guard let record = records.first(where: { $0.id == id }) else { return }
        records.removeAll { $0.id == id }
        deleteFiles(for: record)
        syncItemsFromRecords()
        persistIndex()
    }

    func clearAll() {
        for record in records {
            deleteFiles(for: record)
        }
        records.removeAll()
        syncItemsFromRecords()
        persistIndex()
    }

    func setPinned(id: UUID, pinned: Bool) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].isPinned = pinned
        syncItemsFromRecords()
        persistIndex()
        onPinChanged?(pinned)
    }

    func loadRepresentations(for id: UUID) -> [String: Data]? {
        guard let record = records.first(where: { $0.id == id }) else { return nil }
        if record.isSecure {
            return try? secureStore.load(for: id)
        }
        return try? clipStorage.loadBody(for: id)
    }

    func applyEvictionLimits() {
        runEviction()
        persistIndex()
    }

    private func loadFromDisk() {
        do {
            records = try index.load()
            syncItemsFromRecords()
        } catch {
            Log.error("Failed to load history index: \(error.localizedDescription)")
            records = []
            items = []
        }
    }

    private func syncItemsFromRecords() {
        items = records.map { $0.toClipItem() }
    }

    private func runEviction() {
        var ids = EvictionPolicy.idsToEvict(
            from: records,
            limits: settings.evictionLimits,
            totalBytesOnDisk: clipStorage.totalBytesOnDisk()
        )
        ids.append(contentsOf: EvictionPolicy.expiredSecureIDs(
            from: records,
            maxAge: settings.secureMaxAge
        ))
        ids = Array(Set(ids))
        guard !ids.isEmpty else { return }

        for id in ids {
            guard let record = records.first(where: { $0.id == id }) else { continue }
            records.removeAll { $0.id == id }
            deleteFiles(for: record)
        }
        syncItemsFromRecords()
        Log.info("Evicted \(ids.count) clip(s)")
        onEvicted?(ids.count)
    }

    private func deleteFiles(for record: ClipItemRecord) {
        if record.isSecure {
            secureStore.delete(for: record.id)
        } else {
            clipStorage.deleteItemFiles(for: record.id)
        }
    }

    private func persistIndex() {
        do {
            try index.save(records)
        } catch {
            Log.error("Failed to save history index: \(error.localizedDescription)")
        }
    }
}
