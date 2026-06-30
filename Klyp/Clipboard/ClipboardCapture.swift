import AppKit
import Foundation

struct ClipboardCapture {
    func capture(from pasteboard: NSPasteboard = .general) -> ClipItem? {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }

        var mergedRepresentations: [String: Data] = [:]
        for item in items {
            for type in item.types {
                if let data = item.data(forType: type) {
                    mergedRepresentations[type.rawValue] = data
                }
            }
        }

        enrichImageRepresentations(&mergedRepresentations, from: pasteboard)

        guard let kind = classify(representations: mergedRepresentations) else { return nil }

        let preview = previewText(for: kind, representations: mergedRepresentations)
        let byteSize = mergedRepresentations.values.reduce(0) { $0 + $1.count }
        let source = currentSourceApp()

        return ClipItem(
            kind: kind,
            representations: mergedRepresentations,
            previewText: preview,
            source: source,
            byteSize: byteSize
        )
    }

    private func classify(representations: [String: Data]) -> ClipItemKind? {
        if representations.keys.contains(NSPasteboard.PasteboardType.fileURL.rawValue) {
            return .file
        }
        if containsImageRepresentation(representations) {
            return .image
        }
        if representations.keys.contains(NSPasteboard.PasteboardType.URL.rawValue) {
            return .link
        }
        if representations.keys.contains(where: { $0.contains("Color") || $0 == "org.nspasteboard.ColorType" }) {
            return .color
        }
        if representations.keys.contains(where: {
            $0 == NSPasteboard.PasteboardType.rtf.rawValue
                || $0 == NSPasteboard.PasteboardType.rtfd.rawValue
                || $0 == NSPasteboard.PasteboardType.html.rawValue
        }) {
            return .richText
        }
        if representations.keys.contains(NSPasteboard.PasteboardType.string.rawValue) {
            return .text
        }
        return nil
    }

    private func containsImageRepresentation(_ representations: [String: Data]) -> Bool {
        if representations.keys.contains(where: ImageThumbnail.isImageTypeName) {
            return true
        }
        return ImageThumbnail.imageFromRepresentations(representations) != nil
    }

    private func enrichImageRepresentations(
        _ representations: inout [String: Data],
        from pasteboard: NSPasteboard
    ) {
        if ImageThumbnail.imageFromRepresentations(representations) != nil {
            return
        }

        guard let objects = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
              let image = objects.first
        else { return }

        ImageThumbnail.normalizeSize(image)
        guard let pngData = ImageThumbnail.pngData(from: image) else { return }
        representations[NSPasteboard.PasteboardType.png.rawValue] = pngData
    }

    private func previewText(for kind: ClipItemKind, representations: [String: Data]) -> String? {
        switch kind {
        case .text, .richText, .link:
            if let urlData = representations[NSPasteboard.PasteboardType.URL.rawValue],
               let urlString = String(data: urlData, encoding: .utf8) {
                return urlString
            }
            if let data = representations[NSPasteboard.PasteboardType.string.rawValue] {
                return String(data: data, encoding: .utf8)
            }
            return nil
        case .color:
            return ColorPreview.hexString(from: representations)
        case .image:
            if let image = ImageThumbnail.imageFromRepresentations(representations) {
                let width = Int(image.size.width.rounded())
                let height = Int(image.size.height.rounded())
                return "Image \(width)×\(height)"
            }
            return "Image"
        case .file:
            if let data = representations[NSPasteboard.PasteboardType.fileURL.rawValue],
               let urlString = String(data: data, encoding: .utf8),
               let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return url.lastPathComponent
            }
            return "File"
        }
    }

    private func currentSourceApp() -> SourceApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let name = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        let bundleID = app.bundleIdentifier ?? "unknown"
        return SourceApp(name: name, bundleIdentifier: bundleID)
    }
}

enum ColorPreview {
    static func hexString(from representations: [String: Data]) -> String? {
        if let data = representations["org.nspasteboard.ColorType"],
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return rgbaHex(color.usingColorSpace(.sRGB) ?? color)
        }
        if let data = representations[NSPasteboard.PasteboardType.string.rawValue],
           let text = String(data: data, encoding: .utf8),
           text.hasPrefix("#") {
            return text
        }
        return nil
    }

    static func color(from representations: [String: Data]) -> NSColor? {
        if let data = representations["org.nspasteboard.ColorType"],
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
            return color.usingColorSpace(.sRGB)
        }
        return nil
    }

    static func color(fromHex hex: String) -> NSColor? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    private static func rgbaHex(_ color: NSColor) -> String {
        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
