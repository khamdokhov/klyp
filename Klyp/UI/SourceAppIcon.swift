import AppKit
import SwiftUI

struct SourceAppIcon: View {
    let bundleIdentifier: String

    var body: some View {
        if let icon = AppIconLoader.icon(for: bundleIdentifier) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "app.fill")
                .frame(width: 16, height: 16)
        }
    }
}

enum AppIconLoader {
    static func icon(for bundleIdentifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
