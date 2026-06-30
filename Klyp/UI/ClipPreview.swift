import AppKit
import SwiftUI

struct ClipPreview: View {
    let item: ClipItem

    var body: some View {
        switch item.kind {
        case .text, .richText, .link:
            Text(item.previewText ?? "")
                .lineLimit(2)
                .font(.body)
        case .color:
            HStack(spacing: 8) {
                if let hex = item.previewText, let color = ColorPreview.color(fromHex: hex) {
                    Circle()
                        .fill(Color(nsColor: color))
                        .frame(width: 16, height: 16)
                } else if let color = ColorPreview.color(from: item.representations) {
                    Circle()
                        .fill(Color(nsColor: color))
                        .frame(width: 16, height: 16)
                }
                Text(item.previewText ?? "")
                    .font(.body.monospaced())
            }
        case .image:
            thumbnailView(fallback: "photo")
        case .file:
            HStack(spacing: 8) {
                if let icon = fileIcon(from: item) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "doc")
                }
                Text(item.previewText ?? "File")
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func thumbnailView(fallback: String) -> some View {
        if let image = loadThumbnail() {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 48, maxHeight: 32)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            Image(systemName: fallback)
        }
    }

    private func loadThumbnail() -> NSImage? {
        guard let ref = item.thumbnailRef else { return nil }
        let url = StoragePaths.itemsDirectory.appendingPathComponent(ref)
        return NSImage(contentsOf: url)
    }

    private func fileIcon(from item: ClipItem) -> NSImage? {
        guard let data = item.representations[NSPasteboard.PasteboardType.fileURL.rawValue],
              let urlString = String(data: data, encoding: .utf8),
              let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
