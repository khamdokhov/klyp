import SwiftUI

struct HistorySettings: View {
    @Bindable var settings: AppSettings

    private let maxAgeOptions: [(label: String, days: Int)] = [
        ("Off", 0),
        ("7 days", 7),
        ("30 days", 30),
        ("90 days", 90),
    ]

    var body: some View {
        Form {
            Section("Limits") {
                LabeledContent("Max items") {
                    Slider(
                        value: Binding(
                            get: { Double(settings.maxItems) },
                            set: { settings.maxItems = Int($0) }
                        ),
                        in: 50 ... 500,
                        step: 10
                    )
                    Text("\(settings.maxItems)")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }

                LabeledContent("Max disk usage") {
                    Slider(
                        value: Binding(
                            get: { Double(settings.maxBytes) / 1_048_576 },
                            set: { settings.maxBytes = Int($0) * 1_048_576 }
                        ),
                        in: 50 ... 2000,
                        step: 50
                    )
                    Text("\(settings.maxBytes / 1_048_576) MB")
                        .monospacedDigit()
                        .frame(width: 56, alignment: .trailing)
                }

                Picker("Auto-delete after", selection: $settings.maxAgeDays) {
                    ForEach(maxAgeOptions, id: \.days) { option in
                        Text(option.label).tag(option.days)
                    }
                }
            }

            Section {
                Toggle("Text", isOn: $settings.captureText)
                Toggle("Rich text", isOn: $settings.captureRichText)
                Toggle("Images", isOn: $settings.captureImages)
                Toggle("Files", isOn: $settings.captureFiles)
                Toggle("Links", isOn: $settings.captureLinks)
            } header: {
                Text("Capture")
            } footer: {
                Text("Disabling a type stops new captures only. Existing history is kept.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
