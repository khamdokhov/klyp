import Foundation
import XCTest
@testable import Klyp

final class EvictionPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testEvictsOldestWhenOverMaxItems() {
        let records = [
            makeRecord(createdAt: now.addingTimeInterval(-300)),
            makeRecord(createdAt: now.addingTimeInterval(-200)),
            makeRecord(createdAt: now.addingTimeInterval(-100)),
        ]
        let limits = EvictionLimits(maxItems: 2, maxBytes: Int.max, maxAge: 0)

        let ids = EvictionPolicy.idsToEvict(
            from: records,
            limits: limits,
            totalBytesOnDisk: 0,
            now: now
        )

        XCTAssertEqual(ids.count, 1)
        XCTAssertEqual(ids.first, records[0].id)
    }

    func testPinnedItemsAreExcludedFromCountEviction() {
        var pinned = makeRecord(createdAt: now.addingTimeInterval(-300))
        pinned.isPinned = true
        let records = [
            pinned,
            makeRecord(createdAt: now.addingTimeInterval(-200)),
            makeRecord(createdAt: now.addingTimeInterval(-100)),
        ]
        let limits = EvictionLimits(maxItems: 2, maxBytes: Int.max, maxAge: 0)

        let ids = EvictionPolicy.idsToEvict(
            from: records,
            limits: limits,
            totalBytesOnDisk: 0,
            now: now
        )

        XCTAssertEqual(ids.count, 1)
        XCTAssertEqual(ids.first, records[1].id)
        XCTAssertFalse(ids.contains(pinned.id))
    }

    func testEvictsOldestWhenOverMaxBytes() {
        let records = [
            makeRecord(createdAt: now.addingTimeInterval(-200), byteSize: 400),
            makeRecord(createdAt: now.addingTimeInterval(-100), byteSize: 400),
        ]
        let limits = EvictionLimits(maxItems: 10, maxBytes: 500, maxAge: 0)

        let ids = EvictionPolicy.idsToEvict(
            from: records,
            limits: limits,
            totalBytesOnDisk: 800,
            now: now
        )

        XCTAssertEqual(ids.count, 1)
        XCTAssertEqual(ids.first, records[0].id)
    }

    func testEvictsItemsOlderThanMaxAge() {
        let records = [
            makeRecord(createdAt: now.addingTimeInterval(-100_000)),
            makeRecord(createdAt: now.addingTimeInterval(-100)),
        ]
        let limits = EvictionLimits(maxItems: 10, maxBytes: Int.max, maxAge: 86_400)

        let ids = EvictionPolicy.idsToEvict(
            from: records,
            limits: limits,
            totalBytesOnDisk: 0,
            now: now
        )

        XCTAssertEqual(ids, [records[0].id])
    }

    func testExpiredSecureItemsAreIdentified() {
        let records = [
            makeRecord(createdAt: now.addingTimeInterval(-100_000), isSecure: true),
            makeRecord(createdAt: now.addingTimeInterval(-100), isSecure: true),
        ]

        let ids = EvictionPolicy.expiredSecureIDs(from: records, maxAge: 86_400, now: now)

        XCTAssertEqual(ids, [records[0].id])
    }

    private func makeRecord(
        createdAt: Date,
        byteSize: Int = 100,
        isPinned: Bool = false,
        isSecure: Bool = false
    ) -> ClipItemRecord {
        var item = ClipItem(
            createdAt: createdAt,
            kind: .text,
            previewText: "sample",
            isPinned: isPinned,
            isSecure: isSecure,
            byteSize: byteSize
        )
        item.representations = ["public.utf8-plain-text": Data("sample".utf8)]
        return ClipItemRecord(from: item)
    }
}
