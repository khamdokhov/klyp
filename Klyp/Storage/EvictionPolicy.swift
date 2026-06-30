import Foundation

struct EvictionLimits: Equatable {
    var maxItems: Int
    var maxBytes: Int
    var maxAge: TimeInterval

    static let `default` = EvictionLimits(
        maxItems: 200,
        maxBytes: 500 * 1024 * 1024,
        maxAge: 30 * 24 * 60 * 60
    )
}

struct EvictionPolicy {
    static func idsToEvict(
        from records: [ClipItemRecord],
        limits: EvictionLimits,
        totalBytesOnDisk: Int,
        now: Date = Date()
    ) -> [UUID] {
        var evictable = records
            .filter { !$0.isPinned && !$0.isSecure }
            .sorted { $0.createdAt < $1.createdAt }

        var toEvict: [UUID] = []
        var remaining = records
        var bytes = totalBytesOnDisk

        func removeOldest() {
            guard let oldest = evictable.first else { return }
            evictable.removeFirst()
            remaining.removeAll { $0.id == oldest.id }
            bytes = max(0, bytes - oldest.byteSize)
            toEvict.append(oldest.id)
        }

        if limits.maxAge > 0 {
            let cutoff = now.addingTimeInterval(-limits.maxAge)
            for record in evictable where record.createdAt < cutoff {
                if !toEvict.contains(record.id) {
                    toEvict.append(record.id)
                    remaining.removeAll { $0.id == record.id }
                    bytes = max(0, bytes - record.byteSize)
                }
            }
            evictable.removeAll { toEvict.contains($0.id) }
        }

        while remaining.count > limits.maxItems {
            removeOldest()
        }

        while bytes > limits.maxBytes {
            removeOldest()
        }

        return toEvict
    }

    static func expiredSecureIDs(
        from records: [ClipItemRecord],
        maxAge: TimeInterval,
        now: Date = Date()
    ) -> [UUID] {
        guard maxAge > 0 else { return [] }
        let cutoff = now.addingTimeInterval(-maxAge)
        return records
            .filter { $0.isSecure && !$0.isPinned && $0.createdAt < cutoff }
            .map(\.id)
    }
}
