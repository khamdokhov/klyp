import SwiftUI

struct GeneralSettings: View {
    @Bindable var settings: AppSettings
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        updateLaunchAtLogin(enabled)
                    }

                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Shortcut") {
                LabeledContent("Open history") {
                    HotkeyRecorderView(combination: hotkeyBinding)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private var hotkeyBinding: Binding<HotkeyCombination> {
        Binding(
            get: { settings.hotkeyCombination },
            set: { settings.hotkeyCombination = $0 }
        )
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLogin = LaunchAtLogin.isEnabled
            launchError = nil
        } catch {
            launchAtLogin = LaunchAtLogin.isEnabled
            launchError = error.localizedDescription
        }
    }
}
