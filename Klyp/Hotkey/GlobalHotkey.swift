import Carbon
import Foundation

@MainActor
protocol HotkeyRegistering: AnyObject {
    var onHotkey: (() -> Void)? { get set }
    func register(keyCode: UInt32, modifiers: UInt32)
    func unregister()
    func tearDown()
}

@MainActor
final class GlobalHotkey: HotkeyRegistering {
    var onHotkey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handlerInstalled = false
    private let hotKeyID = EventHotKeyID(signature: OSType(0x424C4F42), id: 1)

    func register(keyCode: UInt32, modifiers: UInt32) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        ensureHandlerInstalled()
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    func tearDown() {
        unregister()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
            handlerInstalled = false
        }
    }

    private func ensureHandlerInstalled() {
        guard !handlerInstalled else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    hotkey.onHotkey?()
                }
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
        handlerInstalled = true
    }
}
