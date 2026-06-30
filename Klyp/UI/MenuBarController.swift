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

    private let symbolPointSize: CGFloat = 14
    private let iconHeight: CGFloat = 18
    private let pixelScale: CGFloat = 2

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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
        applyStatusButtonActiveState(isOpen)
    }

    private func applyStatusButtonActiveState(_ isOpen: Bool) {
        guard let button = statusItem.button else { return }
        button.state = isOpen ? .on : .off
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = "Klyp"
        applyStatusBarImage()
    }

    private func applyStatusBarImage() {
        guard let image = statusBarImage(symbolName: AppSymbol.statusBar) else { return }
        statusItem.button?.image = image
        statusItem.length = image.size.width
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

    private func statusBarImage(symbolName: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Klyp")?
            .withSymbolConfiguration(config)
        else { return nil }

        let pixelHeight = iconHeight * pixelScale
        let pixelWidth = pixelHeight * 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelWidth),
            pixelsHigh: Int(pixelHeight),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.current = context

        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight).fill()

        let symbolSize = symbol.size
        guard symbolSize.width > 0, symbolSize.height > 0 else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }

        let fitScale = min(pixelWidth / symbolSize.width, pixelHeight / symbolSize.height)
        let drawSize = NSSize(width: symbolSize.width * fitScale, height: symbolSize.height * fitScale)
        let origin = NSPoint(
            x: (pixelWidth - drawSize.width) / 2,
            y: (pixelHeight - drawSize.height) / 2
        )
        symbol.draw(
            in: NSRect(origin: origin, size: drawSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        NSGraphicsContext.restoreGraphicsState()

        guard let cropped = croppedTemplateImage(from: bitmap, pixelScale: pixelScale) else { return nil }
        return cropped
    }

    private func croppedTemplateImage(from bitmap: NSBitmapImageRep, pixelScale: CGFloat) -> NSImage? {
        guard let cgImage = bitmap.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else { return nil }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        guard bytesPerPixel >= 4 else { return nil }

        let bytesPerRow = cgImage.bytesPerRow
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var foundPixel = false

        for y in 0 ..< height {
            for x in 0 ..< width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let alpha = bytes[offset + 3]
                if alpha > 8 {
                    foundPixel = true
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard foundPixel else { return nil }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )

        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }

        let image = NSImage(cgImage: croppedCG, size: NSSize(
            width: cropRect.width / pixelScale,
            height: cropRect.height / pixelScale
        ))
        image.isTemplate = true
        return image
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
