import AppKit
import Carbon
import SwiftUI

@MainActor
final class HotkeyRecorderModel {
    var isRecording = false
    private var monitor: Any?
    private var onComplete: ((HotkeyCombination?) -> Void)?

    func startRecording(onComplete: @escaping (HotkeyCombination?) -> Void) {
        stopRecording()
        self.onComplete = onComplete
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return handle(event)
        }
    }

    func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
        onComplete = nil
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyDown {
            if event.keyCode == UInt16(kVK_Escape) {
                finish(with: nil)
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).carbonModifiers
            let combination = HotkeyCombination(keyCode: UInt32(event.keyCode), modifiers: modifiers)
            if combination.isValid {
                finish(with: combination)
                return nil
            }
            return nil
        }
        return event
    }

    private func finish(with combination: HotkeyCombination?) {
        let callback = onComplete
        stopRecording()
        callback?(combination)
    }
}

struct HotkeyRecorderView: View {
    @Binding var combination: HotkeyCombination
    @State private var recorder = HotkeyRecorderModel()
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 8) {
            Text(isRecording ? "Press shortcut…" : combination.displayString)
                .foregroundStyle(isRecording ? .primary : .secondary)
                .frame(minWidth: 72, alignment: .trailing)

            Button(isRecording ? "Cancel" : "Record") {
                if isRecording {
                    recorder.stopRecording()
                    isRecording = false
                } else {
                    isRecording = true
                    recorder.startRecording { newCombination in
                        isRecording = false
                        if let newCombination {
                            combination = newCombination
                        }
                    }
                }
            }
        }
    }
}
