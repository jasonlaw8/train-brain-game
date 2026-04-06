import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    @AppStorage("hapticsEnabled") var hapticsEnabled = true

    var body: some View {
        Form {
            // MARK: Preferences
            Section("Preferences") {
                Toggle(isOn: $hapticsEnabled) {
                    Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                }
            }

            // MARK: About
            Section("About") {
                LabeledContent("App") {
                    Text("TrainBrain")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Version") {
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Spacer()
                    Text("Train your brain daily")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
