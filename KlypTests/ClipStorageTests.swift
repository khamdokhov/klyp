import AppKit
import Foundation
import ImageIO
import XCTest
@testable import Klyp

final class ClipStorageTests: XCTestCase {
    private var tempDirectory: URL?

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KlypTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: XCTUnwrap(tempDirectory), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    func testBodyRoundTrip() throws {
        let tempDirectory = try XCTUnwrap(tempDirectory)
        let storage = ClipStorage(itemsDirectory: tempDirectory)
        let id = UUID()
        let representations = [
            "public.utf8-plain-text": Data("round-trip".utf8),
        ]

        try storage.saveBody(representations, for: id)
        let loaded = try storage.loadBody(for: id)

        XCTAssertEqual(loaded, representations)
    }

    func testDeleteRemovesBodyFile() throws {
        let tempDirectory = try XCTUnwrap(tempDirectory)
        let storage = ClipStorage(itemsDirectory: tempDirectory)
        let id = UUID()
        try storage.saveBody(["public.utf8-plain-text": Data("x".utf8)], for: id)

        storage.deleteItemFiles(for: id)

        XCTAssertThrowsError(try storage.loadBody(for: id))
    }

    func testSaveThumbnailFromPNG() throws {
        let tempDirectory = try XCTUnwrap(tempDirectory)
        let storage = ClipStorage(itemsDirectory: tempDirectory)
        let id = UUID()
        let pngData = try XCTUnwrap(makeSamplePNGData(width: 320, height: 240))

        let ref = try storage.saveThumbnail(
            from: [NSPasteboard.PasteboardType.png.rawValue: pngData],
            kind: .image,
            for: id
        )

        XCTAssertEqual(ref, "\(id.uuidString).thumb.png")
        let url = tempDirectory.appendingPathComponent(try XCTUnwrap(ref))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let thumb = try XCTUnwrap(NSImage(contentsOf: url))
        XCTAssertEqual(thumb.size.width, 96, accuracy: 1)
        XCTAssertEqual(thumb.size.height, 96, accuracy: 1)
    }

    func testSaveThumbnailFromTIFF() throws {
        let tempDirectory = try XCTUnwrap(tempDirectory)
        let storage = ClipStorage(itemsDirectory: tempDirectory)
        let id = UUID()
        let tiffData = try XCTUnwrap(makeSampleTIFFData(width: 800, height: 600))

        let ref = try storage.saveThumbnail(
            from: [NSPasteboard.PasteboardType.tiff.rawValue: tiffData],
            kind: .image,
            for: id
        )

        XCTAssertNotNil(ref)
        let url = tempDirectory.appendingPathComponent(try XCTUnwrap(ref))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 0)
    }

    private func makeSamplePNGData(width: Int, height: Int) -> Data? {
        guard let cgImage = makeSampleCGImage(width: width, height: height) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    private func makeSampleTIFFData(width: Int, height: Int) -> Data? {
        guard let cgImage = makeSampleCGImage(width: width, height: height) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .tiff, properties: [:])
    }

    private func makeSampleCGImage(width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

final class ClipboardCaptureTests: XCTestCase {
    func testClassifiesImageBeforeLinkWhenBothPresent() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("KlypTests-\(UUID().uuidString)"))
        pasteboard.clearContents()

        let pngData = makeSamplePNGData(width: 64, height: 64)
        let urlData = Data("https://example.com/photo.jpg".utf8)
        let item = NSPasteboardItem()
        item.setData(pngData, forType: .png)
        item.setData(urlData, forType: .URL)
        pasteboard.writeObjects([item])

        let captured = ClipboardCapture().capture(from: pasteboard)

        XCTAssertEqual(captured?.kind, .image)
        XCTAssertNotNil(captured?.representations[NSPasteboard.PasteboardType.png.rawValue])
    }

    func testCapturesTIFFScreenshotStyleClip() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("KlypTests-\(UUID().uuidString)"))
        pasteboard.clearContents()

        let tiffData = makeSampleTIFFData(width: 1440, height: 900)
        let item = NSPasteboardItem()
        item.setData(tiffData, forType: .tiff)
        pasteboard.writeObjects([item])

        let captured = ClipboardCapture().capture(from: pasteboard)

        XCTAssertEqual(captured?.kind, .image)
        XCTAssertNotNil(captured?.representations[NSPasteboard.PasteboardType.tiff.rawValue])
    }

    private func makeSamplePNGData(width: Int, height: Int) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        return rep.representation(using: .png, properties: [:])!
    }

    private func makeSampleTIFFData(width: Int, height: Int) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0, green: 0.8, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        return rep.representation(using: .tiff, properties: [:])!
    }
}
