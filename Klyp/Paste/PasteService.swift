import AppKit

@MainActor
protocol Pasting: AnyObject {
    func copyToPasteboard(_ item: ClipItem)
}

@MainActor
final class PasteService: Pasting {
    private let pasteboard: NSPasteboard
    private let historyStore: HistoryStore
    private weak var monitor: PasteboardMonitor?
    var onCopied: (() -> Void)?

    init(
        pasteboard: NSPasteboard = .general,
        historyStore: HistoryStore,
        monitor: PasteboardMonitor
    ) {
        self.pasteboard = pasteboard
        self.historyStore = historyStore
        self.monitor = monitor
    }

    func copyToPasteboard(_ item: ClipItem) {
        var representations = item.representations
        if representations.isEmpty {
            representations = historyStore.loadRepresentations(for: item.id) ?? [:]
        }
        guard !representations.isEmpty else {
            Log.error("No representations available for clip \(item.id.uuidString.prefix(8))")
            return
        }

        let expectedCount = pasteboard.changeCount + 1
        monitor?.expectNextChangeCount(expectedCount)

        pasteboard.clearContents()
        for (type, data) in representations {
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
        }
        onCopied?()
    }
}
