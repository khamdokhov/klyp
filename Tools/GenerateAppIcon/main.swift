import AppKit
import Foundation

// Generates the Klyp app icon set and writes it into the asset catalog.
// Run from the repository root: cat Tools/AppSymbol.swift Tools/GenerateAppIcon/main.swift | swift -

struct IconSpec {
    let logicalSize: Int
    let scale: Int
    let pixelSize: Int
    let filename: String
}

let specs: [IconSpec] = [
    IconSpec(logicalSize: 16, scale: 1, pixelSize: 16, filename: "icon_16x16.png"),
    IconSpec(logicalSize: 16, scale: 2, pixelSize: 32, filename: "icon_16x16@2x.png"),
    IconSpec(logicalSize: 32, scale: 1, pixelSize: 32, filename: "icon_32x32.png"),
    IconSpec(logicalSize: 32, scale: 2, pixelSize: 64, filename: "icon_32x32@2x.png"),
    IconSpec(logicalSize: 128, scale: 1, pixelSize: 128, filename: "icon_128x128.png"),
    IconSpec(logicalSize: 128, scale: 2, pixelSize: 256, filename: "icon_128x128@2x.png"),
    IconSpec(logicalSize: 256, scale: 1, pixelSize: 256, filename: "icon_256x256.png"),
    IconSpec(logicalSize: 256, scale: 2, pixelSize: 512, filename: "icon_256x256@2x.png"),
    IconSpec(logicalSize: 512, scale: 1, pixelSize: 512, filename: "icon_512x512.png"),
    IconSpec(logicalSize: 512, scale: 2, pixelSize: 1024, filename: "icon_512x512@2x.png"),
]

struct Palette {
    static let background = NSColor(calibratedRed: 0.17, green: 0.18, blue: 0.20, alpha: 1)
}

func repositoryRoot() -> URL {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("Klyp.xcodeproj").path) {
        return cwd
    }
    let sourceFile = URL(fileURLWithPath: #filePath)
    return sourceFile.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
}

func squirclePath(in rect: CGRect, cornerRadius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
}

func drawIcon(pixelSize: CGFloat) -> NSBitmapImageRep {
    let pixels = Int(pixelSize)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to allocate bitmap for \(pixelSize)px icon")
    }

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context

    let bounds = CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let squircle = squirclePath(in: bounds, cornerRadius: pixelSize * 0.223)

    context.cgContext.saveGState()
    squircle.addClip()
    Palette.background.setFill()
    bounds.fill()

    let config = NSImage.SymbolConfiguration(pointSize: pixelSize * 0.52, weight: .medium)
        .applying(.preferringMulticolor())
    if let symbol = NSImage(systemSymbolName: AppSymbol.appIcon, accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        let symbolSize = symbol.size
        if symbolSize.width > 0, symbolSize.height > 0 {
            let fitScale = min(
                (pixelSize * 0.72) / symbolSize.width,
                (pixelSize * 0.72) / symbolSize.height
            )
            let drawSize = NSSize(width: symbolSize.width * fitScale, height: symbolSize.height * fitScale)
            let origin = NSPoint(
                x: (pixelSize - drawSize.width) / 2,
                y: (pixelSize - drawSize.height) / 2
            )
            symbol.draw(in: NSRect(origin: origin, size: drawSize), from: .zero, operation: .sourceOver, fraction: 1)
        }
    }

    context.cgContext.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) throws {
    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GenerateAppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG export failed"])
    }
    try png.write(to: url, options: .atomic)
}

func writeContentsJSON(to directory: URL) throws {
    let images = specs.map { spec in
        """
            {
              "filename" : "\(spec.filename)",
              "idiom" : "mac",
              "scale" : "\(spec.scale)x",
              "size" : "\(spec.logicalSize)x\(spec.logicalSize)"
            }
        """
    }.joined(separator: ",\n")

    let json = """
    {
      "images" : [
    \(images)
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try json.write(to: directory.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

let root = repositoryRoot()
let iconset = root
    .appendingPathComponent("Klyp/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for spec in specs {
    let rep = drawIcon(pixelSize: CGFloat(spec.pixelSize))
    try writePNG(rep, to: iconset.appendingPathComponent(spec.filename))
    print("Wrote \(spec.filename) (\(spec.pixelSize)px)")
}

try writeContentsJSON(to: iconset)
print("Updated AppIcon.appiconset at \(iconset.path)")
