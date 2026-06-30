import AppKit
import Foundation
import XCTest
@testable import Klyp

@MainActor
final class HistoryStoreTests: XCTestCase {
    private var tempDirectory: URL?
    private var settings: AppSettings?
    private var store: HistoryStore?

    override func setUp() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KlypTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempDirectory = directory

        let settings = AppSettings()
        self.settings = settings
        store = HistoryStore(
            index: HistoryIndex(fileURL: directory.appendingPathComponent("index.json")),
            clipStorage: ClipStorage(itemsDirectory: directory.appendingPathComponent("items")),
            settings: settings
        )
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        store = nil
        settings = nil
    }

    func testInsertAndLoadRepresentations() throws {
        let store = try XCTUnwrap(store)
        let item = makeTextItem(text: "persist me")

        let result = store.add(item)

        XCTAssertEqual(result, .inserted)
        XCTAssertEqual(store.items.count, 1)
        let loaded = store.loadRepresentations(for: item.id)
        XCTAssertEqual(loaded?["public.utf8-plain-text"], Data("persist me".utf8))
    }

    func testDeduplicatesMatchingTextItems() throws {
        let store = try XCTUnwrap(store)
        let first = makeTextItem(text: "duplicate")
        let second = makeTextItem(text: "duplicate")

        XCTAssertEqual(store.add(first), .inserted)
        let result = store.add(second)

        guard case let .deduplicated(existingID) = result else {
            return XCTFail("Expected deduplicated result")
        }
        XCTAssertEqual(existingID, first.id)
        XCTAssertEqual(store.items.count, 1)
    }

    func testSurvivesRestart() throws {
        let store = try XCTUnwrap(store)
        let tempDirectory = try XCTUnwrap(tempDirectory)
        let settings = try XCTUnwrap(settings)
        let item = makeTextItem(text: "survive restart")
        XCTAssertEqual(store.add(item), .inserted)

        let reloaded = HistoryStore(
            index: HistoryIndex(fileURL: tempDirectory.appendingPathComponent("index.json")),
            clipStorage: ClipStorage(itemsDirectory: tempDirectory.appendingPathComponent("items")),
            settings: settings
        )

        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.previewText, "survive restart")
        let loaded = reloaded.loadRepresentations(for: item.id)
        XCTAssertEqual(loaded?["public.utf8-plain-text"], Data("survive restart".utf8))
    }

    func testImageClipPersistsThumbnailRef() throws {
        let store = try XCTUnwrap(store)
        let tempDirectory = try XCTUnwrap(tempDirectory)
        let itemsDirectory = tempDirectory.appendingPathComponent("items")
        let pngData = try XCTUnwrap(makeSamplePNGData())
        let item = ClipItem(
            kind: .image,
            representations: [NSPasteboard.PasteboardType.png.rawValue: pngData],
            previewText: "Image",
            byteSize: pngData.count
        )

        XCTAssertEqual(store.add(item), .inserted)
        let stored = try XCTUnwrap(store.items.first)
        XCTAssertNotNil(stored.thumbnailRef)

        let thumbURL = itemsDirectory.appendingPathComponent(try XCTUnwrap(stored.thumbnailRef))
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbURL.path))

        let reloaded = HistoryStore(
            index: HistoryIndex(fileURL: tempDirectory.appendingPathComponent("index.json")),
            clipStorage: ClipStorage(itemsDirectory: itemsDirectory),
            settings: try XCTUnwrap(settings)
        )
        XCTAssertEqual(reloaded.items.first?.thumbnailRef, stored.thumbnailRef)
    }

    private func makeSamplePNGData() -> Data? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 120,
            height: 80,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 80))
        guard let cgImage = context.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    private func makeTextItem(text: String) -> ClipItem {
        ClipItem(
            kind: .text,
            representations: ["public.utf8-plain-text": Data(text.utf8)],
            previewText: text,
            byteSize: text.utf8.count
        )
    }
}
