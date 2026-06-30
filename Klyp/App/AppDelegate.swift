import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var environment: AppEnvironment?
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        var environment = AppEnvironment()
        let settingsWindowController = SettingsWindowController(settings: environment.settings)
        self.settingsWindowController = settingsWindowController

        let menuBarController = MenuBarController(
            historyStore: environment.historyStore,
            pasteService: environment.pasteService,
            settings: environment.settings,
            globalHotkey: environment.globalHotkey,
            settingsWindowController: settingsWindowController
        )
        self.menuBarController = menuBarController

        environment.onClipFeedback = { [weak menuBarController] feedback in
            menuBarController?.playCaptureFeedback(feedback)
        }
        self.environment = environment
        environment.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment?.stop()
        menuBarController?.tearDown()
    }
}
