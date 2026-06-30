import AppKit
import SwiftUI

struct ClipRowView: View {
    let item: ClipItem
    let isSelected: Bool
    let isHovered: Bool
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            rowContent
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onTapGesture {
                    onTap?()
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var rowContent: some View {
        HStack(spacing: 10) {
            leadingPreview

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(subtitleText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if item.isSecure {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Stored in Keychain")
            }
        }
    }

    private var leadingPreview: some View {
        ZStack(alignment: .bottomTrailing) {
            previewContent
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )

            if let source = item.source {
                SourceAppIcon(bundleIdentifier: source.bundleIdentifier)
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1)
                    }
                    .offset(x: 4, y: 4)
                    .help(source.name)
            }
        }
        .frame(width: 44, height: 44)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.kind {
        case .image:
            if let image = loadThumbnail() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                typeSymbol
            }
        case .color:
            if let color = previewColor {
                color
            } else {
                typeSymbol
            }
        case .file:
            if let icon = fileIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            } else {
                typeSymbol
            }
        default:
            typeSymbol
        }
    }

    private var typeSymbol: some View {
        Image(systemName: kindSymbol)
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        }
        if isHovered {
            return Color.primary.opacity(0.06)
        }
        return Color.clear
    }

    private var titleText: String {
        switch item.kind {
        case .text, .richText, .link:
            item.previewText ?? item.kind.rawValue.capitalized
        case .image:
            item.previewText ?? "Image"
        case .color:
            item.previewText ?? "Color"
        case .file:
            item.previewText ?? "File"
        }
    }

    private var subtitleText: String {
        let source = item.source?.name ?? "Unknown"
        return "\(source) · \(relativeDate(item.createdAt))"
    }

    private var kindSymbol: String {
        if item.isSecure {
            return "lock.doc"
        }
        switch item.kind {
        case .text: return "doc.text"
        case .richText: return "doc.richtext"
        case .link: return "link"
        case .color: return "paintpalette"
        case .image: return "photo"
        case .file: return "doc"
        }
    }

    private var previewColor: Color? {
        if let hex = item.previewText, let color = ColorPreview.color(fromHex: hex) {
            return Color(nsColor: color)
        }
        if let color = ColorPreview.color(from: item.representations) {
            return Color(nsColor: color)
        }
        return nil
    }

    private var fileIcon: NSImage? {
        guard let data = item.representations[NSPasteboard.PasteboardType.fileURL.rawValue],
              let urlString = String(data: data, encoding: .utf8),
              let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func loadThumbnail() -> NSImage? {
        guard let ref = item.thumbnailRef else { return nil }
        let url = StoragePaths.itemsDirectory.appendingPathComponent(ref)
        guard FileManager.default.fileExists(atPath: url.path),
              let image = NSImage(contentsOf: url)
        else { return nil }
        image.size = NSSize(width: 40, height: 40)
        return image
    }

    private var accessibilityLabel: String {
        var parts = ["\(titleText), from \(item.source?.name ?? "Unknown source")"]
        if item.isPinned {
            parts.append("pinned")
        }
        if item.isSecure {
            parts.append("stored securely")
        }
        return parts.joined(separator: ", ")
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
