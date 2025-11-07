import SwiftUI
import SwiftData
import ScoreMatchingKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Query(sort: \Interval.date) var intervals: [Interval]

    @AppStorage("shouldAllowNegativePoints") var shouldAllowNegativePoints: Bool = false
    @AppStorage("hasEnabledIntervals") var hasEnabledIntervals: Bool = false

    @State private var showResetAlert = false
    @State private var showReinitializeAlert = false

    private let syncCoordinator = WatchConnectivityManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Settings section
                Section("Preferences") {
                    Toggle("Negative Points", isOn: $shouldAllowNegativePoints)
                    Toggle("Intervals", isOn: $hasEnabledIntervals)
                }

                // Actions section
                Section {
                    Button("Reset Scores") {
                        showResetAlert = true
                    }

                    Button("Reinitialize App", role: .destructive) {
                        showReinitializeAlert = true
                    }
                }

                // Info section
                Section("Teams") {
                    Text("\(teams.count) teams")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Scores?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetScores()
                }
            } message: {
                Text("All team scores will be set to 0.")
            }
            .alert("Reinitialize App?", isPresented: $showReinitializeAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reinitialize", role: .destructive) {
                    reinitializeApp()
                }
            } message: {
                Text("The app will delete all teams, scores, and intervals, and start with Team A and Team B.")
            }
        }
    }

    // MARK: - Actions

    private func resetScores() {
        teams.forEach { $0.score = [] }
        // Sync to iPhone
        syncCoordinator.sendResetScores()
    }

    private func reinitializeApp() {
        teams.forEach { modelContext.delete($0) }
        intervals.forEach { modelContext.delete($0) }
        Team.createBaseData(modelContext: modelContext)
        // Sync to iPhone
        syncCoordinator.sendReinitializeApp()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Team.self, Interval.self], inMemory: true)
}
