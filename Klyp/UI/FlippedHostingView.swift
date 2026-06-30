import AppKit
import SwiftUI

@MainActor
final class HistoryPanelContainerView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class FlippedHostingController<Content: View>: NSHostingController<Content> {
    private let containerView: HistoryPanelContainerView

    init(rootView: Content, size: NSSize) {
        containerView = HistoryPanelContainerView(frame: NSRect(origin: .zero, size: size))
        super.init(rootView: rootView)
        view.frame = containerView.bounds
        view.autoresizingMask = [.width, .height]
        containerView.addSubview(view)
        containerView.autoresizingMask = [.width, .height]
        self.view = containerView
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateRootView(_ rootView: Content) {
        self.rootView = rootView
    }
}
