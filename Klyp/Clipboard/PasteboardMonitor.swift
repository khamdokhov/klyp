import AppKit
import Foundation

@MainActor
protocol PasteboardMonitoring: AnyObject {
    var onCapture: ((ClipItem) -> Void)? { get set }
    func start()
    func stop()
    func pause()
    func resume()
    func expectNextChangeCount(_ changeCount: Int)
}

@MainActor
final class PasteboardMonitor: PasteboardMonitoring {
    var onCapture: ((ClipItem) -> Void)?

    private let pasteboard: NSPasteboard
    private let capture: ClipboardCapture
    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoredChangeCount: Int?
    private var isPaused = false
    private let pollInterval: TimeInterval = 0.4

    init(pasteboard: NSPasteboard = .general, capture: ClipboardCapture = ClipboardCapture()) {
        self.pasteboard = pasteboard
        self.capture = capture
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
        lastChangeCount = pasteboard.changeCount
    }

    func expectNextChangeCount(_ changeCount: Int) {
        ignoredChangeCount = changeCount
    }

    private func poll() {
        guard !isPaused else { return }

        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }

        if let ignored = ignoredChangeCount, currentCount == ignored {
            ignoredChangeCount = nil
            lastChangeCount = currentCount
            return
        }

        lastChangeCount = currentCount

        guard let item = capture.capture(from: pasteboard) else { return }
        onCapture?(item)
    }
}
