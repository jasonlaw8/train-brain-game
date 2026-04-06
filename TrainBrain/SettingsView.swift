import SwiftUI
import SwiftData

// MARK: - SettingsView

struct SettingsView: View {
    // Haptics
    @AppStorage("hapticsEnabled") var hapticsEnabled = true

    // Notifications
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("notificationHour")     private var notificationHour = 9
    @AppStorage("notificationMinute")   private var notificationMinute = 0

    // Streak (for streak-aware notification body on reschedule)
    @Query private var statsQuery: [PlayerStats]
    @Environment(\.modelContext) private var modelContext
    private var stats: PlayerStats {
        if let s = statsQuery.first { return s }
        let s = PlayerStats(); modelContext.insert(s); return s
    }

    @State private var showPermissionDeniedAlert = false
    @State private var showClearHistoryConfirm = false
    @State private var notificationTime: Date = {
        var c = DateComponents(); c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()

    var body: some View {
        Form {
            // MARK: Notifications
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Daily Reminder", systemImage: "bell.fill")
                }
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        Task {
                            let granted = await NotificationManager.shared.requestPermission()
                            if granted {
                                reschedule()
                            } else {
                                notificationsEnabled = false
                                showPermissionDeniedAlert = true
                            }
                        }
                    } else {
                        NotificationManager.shared.cancelReminder()
                    }
                }

                if notificationsEnabled {
                    DatePicker(
                        "Remind me at",
                        selection: $notificationTime,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: notificationTime) { _, newTime in
                        let cal = Calendar.current
                        notificationHour   = cal.component(.hour,   from: newTime)
                        notificationMinute = cal.component(.minute, from: newTime)
                        reschedule()
                    }
                    .onAppear {
                        // Sync picker to stored values
                        var c = DateComponents()
                        c.hour   = notificationHour
                        c.minute = notificationMinute
                        if let d = Calendar.current.date(from: c) { notificationTime = d }
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("One reminder per day, never more. We'll include your streak count so you know what's at stake.")
            }

            // MARK: iCloud Sync
            Section {
                HStack {
                    Label("iCloud Sync", systemImage: "icloud.slash")
                    Spacer()
                    Text("Coming Soon").foregroundStyle(.secondary)
                }
            } header: {
                Text("iCloud Sync")
            } footer: {
                Text("Cross-device sync will be available in a future update.")
            }

            // MARK: Preferences
            Section("Preferences") {
                Toggle(isOn: $hapticsEnabled) {
                    Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                }
            }

            // MARK: Data
            Section {
                Button(role: .destructive) {
                    showClearHistoryConfirm = true
                } label: {
                    Label("Clear All History", systemImage: "trash.fill")
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Permanently deletes all scores, Brain Score history, XP, streaks, and achievements. This cannot be undone.")
            }

            // MARK: About
            Section("About") {
                LabeledContent("App") {
                    Text("TrainBrain").foregroundStyle(.secondary)
                }
                LabeledContent("Version") {
                    Text("1.0").foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Text("Train your brain daily")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear All History?", isPresented: $showClearHistoryConfirm) {
            Button("Clear Everything", role: .destructive) { clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All scores, Brain Score history, XP, streaks, and achievements will be permanently deleted.")
        }
        .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To receive daily reminders, enable notifications for Train Brain in iOS Settings.")
        }
    }

    private func clearHistory() {
        // Reset all stats on the PlayerStats record
        stats.resetAllStats()
        // Delete all GameSession history records
        try? modelContext.delete(model: GameSession.self)
    }

    private func reschedule() {
        NotificationManager.shared.scheduleDailyReminder(
            hour: notificationHour,
            minute: notificationMinute,
            streakCount: stats.dailyStreakCount
        )
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(for: PlayerStats.self, inMemory: true)
}
