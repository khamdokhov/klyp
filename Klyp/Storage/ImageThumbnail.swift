import AppKit
import ImageIO

enum ImageThumbnail {
    static let pointSize: CGFloat = 48
    static let scale: CGFloat = 2

    static let imageTypePriority: [String] = [
        NSPasteboard.PasteboardType.png.rawValue,
        NSPasteboard.PasteboardType.tiff.rawValue,
        "public.jpeg",
        "public.jpg",
        "com.compuserve.gif",
        "public.heic",
        "public.heif",
        "com.apple.icns",
        "public.image",
        "Apple PNG pasteboard type",
        "NeXT TIFF v4.0 pasteboard type",
        "JPEG",
        "GIF",
    ]

    static func isImageTypeName(_ type: String) -> Bool {
        let lowered = type.lowercased()
        return type == NSPasteboard.PasteboardType.png.rawValue
            || type == NSPasteboard.PasteboardType.tiff.rawValue
            || lowered.contains("png")
            || lowered.contains("tiff")
            || lowered.contains("jpeg")
            || lowered.contains("jpg")
            || lowered.contains("gif")
            || lowered.contains("heic")
            || lowered.contains("heif")
            || lowered.contains("image")
            || lowered.contains("icns")
    }

    static func imageFromRepresentations(_ representations: [String: Data]) -> NSImage? {
        for type in imageTypePriority {
            if let data = representations[type], let image = decodeImage(from: data) {
                return image
            }
        }

        for (type, data) in representations where isImageTypeName(type) {
            if let image = decodeImage(from: data) {
                return image
            }
        }

        for (_, data) in representations {
            if let image = decodeImage(from: data), imageLooksLikeBitmap(image) {
                return image
            }
        }

        return nil
    }

    static func decodeImage(from data: Data) -> NSImage? {
        guard !data.isEmpty else { return nil }

        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )
        }

        if let image = NSImage(data: data) {
            normalizeSize(image)
            if image.size.width > 0, image.size.height > 0 {
                return image
            }
        }

        return nil
    }

    static func normalizeSize(_ image: NSImage) {
        if image.size.width > 0, image.size.height > 0 { return }

        if let rep = image.representations.first as? NSBitmapImageRep,
           rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            image.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            return
        }

        var rect = CGRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            image.size = NSSize(width: cgImage.width, height: cgImage.height)
        }
    }

    static func pngData(from image: NSImage) -> Data? {
        normalizeSize(image)
        guard let cgImage = cgImage(from: image) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    static func aspectFitPNG(from image: NSImage, pointSize: CGFloat = pointSize, scale: CGFloat = scale) -> Data? {
        normalizeSize(image)
        guard let cgImage = cgImage(from: image) else { return nil }

        let pixelSize = pointSize * scale
        let srcWidth = CGFloat(cgImage.width)
        let srcHeight = CGFloat(cgImage.height)
        guard srcWidth > 0, srcHeight > 0 else { return nil }

        let fitScale = min(pixelSize / srcWidth, pixelSize / srcHeight)
        let drawWidth = srcWidth * fitScale
        let drawHeight = srcHeight * fitScale
        let originX = (pixelSize - drawWidth) / 2
        let originY = (pixelSize - drawHeight) / 2

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: Int(pixelSize),
                  height: Int(pixelSize),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        context.interpolationQuality = .high
        context.draw(
            cgImage,
            in: CGRect(x: originX, y: originY, width: drawWidth, height: drawHeight)
        )

        guard let output = context.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: output)
        return rep.representation(using: .png, properties: [:])
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cgImage
        }
        if let rep = image.representations.first as? NSBitmapImageRep {
            return rep.cgImage
        }
        return nil
    }

    private static func imageLooksLikeBitmap(_ image: NSImage) -> Bool {
        normalizeSize(image)
        return image.size.width >= 8 && image.size.height >= 8
    }
}
