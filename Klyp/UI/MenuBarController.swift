import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let historyStore: HistoryStore
    private let pasteService: PasteService
    private let settings: AppSettings
    private let globalHotkey: GlobalHotkey
    private let settingsWindowController: SettingsWindowController
    private var historyPanel: HistoryPanelController?
    private var isSearching = false
    private var isPopoverOpen = false
    private var statusBarClickMonitor: Any?
    private let symbolImageView = NSImageView()

    private let symbolPointSize: CGFloat = 14
    private let canvasPointSize: CGFloat = 21
    private let pixelScale: CGFloat = 2
    private let symbolName = AppSymbol.statusBar
    private let activeSymbolName = AppSymbol.statusBarActive

    init(
        historyStore: HistoryStore,
        pasteService: PasteService,
        settings: AppSettings,
        globalHotkey: GlobalHotkey,
        settingsWindowController: SettingsWindowController
    ) {
        self.historyStore = historyStore
        self.pasteService = pasteService
        self.settings = settings
        self.globalHotkey = globalHotkey
        self.settingsWindowController = settingsWindowController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureStatusButton()
        ensureHistoryPanel()
        installStatusBarClickMonitor()
        settings.onHotkeyChanged = { [weak self] in
            self?.applyHotkey()
        }
        applyHotkey()
    }

    func tearDown() {
        globalHotkey.tearDown()
        if let statusBarClickMonitor {
            NSEvent.removeMonitor(statusBarClickMonitor)
            self.statusBarClickMonitor = nil
        }
        historyPanel?.tearDown()
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func setPopoverOpen(_ isOpen: Bool) {
        guard isPopoverOpen != isOpen else { return }
        isPopoverOpen = isOpen
        updateStatusBarImage()
        applyStatusButtonActiveState(isOpen)
    }

    private func applyStatusButtonActiveState(_ isOpen: Bool) {
        guard let button = statusItem.button else { return }
        button.state = isOpen ? .on : .off
    }

    func playCaptureFeedback(_ feedback: StatusBarClipFeedback) {
        guard feedback == .captured,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        else { return }

        if #available(macOS 14.0, *) {
            symbolImageView.addSymbolEffect(.bounce, options: .nonRepeating)
        }
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }

        symbolImageView.image = statusBarImage(symbolName: symbolName)
        symbolImageView.imageScaling = .scaleProportionallyDown
        symbolImageView.contentTintColor = .labelColor
        symbolImageView.translatesAutoresizingMaskIntoConstraints = false

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(symbolImageView)
        NSLayoutConstraint.activate([
            symbolImageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            symbolImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            symbolImageView.widthAnchor.constraint(equalToConstant: canvasPointSize),
            symbolImageView.heightAnchor.constraint(equalToConstant: canvasPointSize),
        ])

        button.image = nil
        button.imagePosition = .imageOnly
        button.toolTip = "Klyp"
    }

    private func installStatusBarClickMonitor() {
        statusBarClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self, let button = self.statusItem.button, button.window != nil else { return event }

            let locationInButton = button.convert(event.locationInWindow, from: nil)
            guard button.bounds.contains(locationInButton) else { return event }

            self.showContextMenu()
            return nil
        }
    }

    private func ensureHistoryPanel() {
        guard historyPanel == nil else { return }

        historyPanel = HistoryPanelController(
            historyStore: historyStore,
            pasteService: pasteService,
            onOpenSettings: { [weak self] in
                self?.settingsWindowController.show()
            },
            onOpen: { [weak self] in
                self?.setPopoverOpen(true)
            },
            onClose: { [weak self] in
                self?.isSearching = false
                self?.setPopoverOpen(false)
                self?.attachHistoryMenu()
            },
            onSearchActiveChanged: { [weak self] isActive in
                self?.isSearching = isActive
            }
        )
        attachHistoryMenu()
    }

    private func attachHistoryMenu() {
        guard let historyPanel else { return }
        historyPanel.rebuildContent()
        statusItem.menu = historyPanel.statusMenu
    }

    private func updateStatusBarImage() {
        let name = isPopoverOpen ? activeSymbolName : symbolName
        symbolImageView.image = statusBarImage(symbolName: name)
    }

    private func statusBarImage(symbolName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Klyp")?
            .withSymbolConfiguration(config)
        else { return nil }

        let pixelCanvas = canvasPointSize * pixelScale
        let canvas = NSImage(size: NSSize(width: pixelCanvas, height: pixelCanvas))
        canvas.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: NSSize(width: pixelCanvas, height: pixelCanvas)).fill()

        let symbolSize = symbol.size
        guard symbolSize.width > 0, symbolSize.height > 0 else {
            canvas.unlockFocus()
            return nil
        }
        let fitScale = min(
            (pixelCanvas * 0.9) / symbolSize.width,
            (pixelCanvas * 0.9) / symbolSize.height
        )
        let drawSize = NSSize(width: symbolSize.width * fitScale, height: symbolSize.height * fitScale)
        let origin = NSPoint(
            x: (pixelCanvas - drawSize.width) / 2,
            y: (pixelCanvas - drawSize.height) / 2
        )
        symbol.draw(in: NSRect(origin: origin, size: drawSize), from: .zero, operation: .sourceOver, fraction: 1)
        canvas.unlockFocus()
        canvas.isTemplate = true
        canvas.size = NSSize(width: canvasPointSize, height: canvasPointSize)
        return canvas
    }

    func applyHotkey() {
        globalHotkey.onHotkey = { [weak self] in
            self?.togglePanelFromHotkey()
        }
        let combination = settings.hotkeyCombination
        globalHotkey.register(keyCode: combination.keyCode, modifiers: combination.modifiers)
    }

    private func togglePanelFromHotkey() {
        ensureHistoryPanel()
        if historyPanel?.isVisible == true {
            closePanel()
        } else {
            statusItem.button?.performClick(nil)
        }
    }

    private func closePanel() {
        historyPanel?.close()
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Klyp",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        attachHistoryMenu()
    }

    @objc private func openSettings(_ sender: Any?) {
        settingsWindowController.show()
    }

    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(sender)
    }
}
