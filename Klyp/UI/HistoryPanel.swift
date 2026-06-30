import AppKit
import SwiftUI

@MainActor
final class HistoryPanelController: NSObject, NSMenuDelegate {
    private let menu: NSMenu
    private let menuItem: NSMenuItem
    private var hostingController: FlippedHostingController<HistoryView>?
    private let historyStore: HistoryStore
    private let pasteService: PasteService
    private let onOpenSettings: () -> Void
    private let onClose: () -> Void
    private let onOpen: () -> Void
    private let onSearchActiveChanged: (Bool) -> Void
    private var isOpen = false

    private static let panelSize = NSSize(width: 340, height: 420)

    init(
        historyStore: HistoryStore,
        pasteService: PasteService,
        onOpenSettings: @escaping () -> Void,
        onOpen: @escaping () -> Void = {},
        onClose: @escaping () -> Void = {},
        onSearchActiveChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.historyStore = historyStore
        self.pasteService = pasteService
        self.onOpenSettings = onOpenSettings
        self.onOpen = onOpen
        self.onClose = onClose
        self.onSearchActiveChanged = onSearchActiveChanged

        menu = NSMenu()
        menuItem = NSMenuItem()
        super.init()

        menu.delegate = self
        menuItem.isEnabled = false
        menu.addItem(menuItem)
        rebuildContent()
    }

    var statusMenu: NSMenu {
        menu
    }

    var isVisible: Bool {
        isOpen
    }

    func rebuildContent() {
        let view = makeHistoryView()
        if let hostingController {
            hostingController.updateRootView(view)
        } else {
            let controller = FlippedHostingController(
                rootView: view,
                size: Self.panelSize
            )
            menuItem.view = controller.view
            hostingController = controller
        }
    }

    func close() {
        menu.cancelTracking()
    }

    func tearDown() {
        close()
    }

    func menuWillOpen(_ notification: Notification) {
        guard !isOpen else { return }
        isOpen = true
        rebuildContent()
        onOpen()
    }

    func menuDidClose(_ notification: Notification) {
        finishClose()
    }

    private func finishClose() {
        guard isOpen else { return }
        isOpen = false
        onSearchActiveChanged(false)
        onClose()
    }

    private func makeHistoryView() -> HistoryView {
        HistoryView(
            historyStore: historyStore,
            onSelect: { [weak self] item in
                self?.close()
                self?.pasteService.copyToPasteboard(item)
            },
            onClose: { [weak self] in
                self?.close()
            },
            onOpenSettings: { [weak self] in
                self?.onOpenSettings()
            },
            onSearchActiveChanged: { [weak self] isActive in
                self?.onSearchActiveChanged(isActive)
            }
        )
    }
}
