import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettings(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            HistorySettings(settings: settings)
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            PrivacySettings(settings: settings)
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
        }
        .frame(width: 520, height: 420)
    }
}
