import SwiftUI
import SwiftData
import WhatScoreKit

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.watchSyncCoordinator) var watchSyncCoordinator

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Query(sort: \Interval.date) var intervals: [Interval]

    @AppStorage("shouldAllowNegativePoints") var shouldAllowNegativePoints: Bool = false
    @AppStorage("hasEnabledIntervals") var hasEnabledIntervals: Bool = false

    @State private var showResetAlert = false
    @State private var showReinitializeAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Settings section
                Section("Preferences") {
                    Toggle("Negative Points", isOn: $shouldAllowNegativePoints)
                        .onChange(of: shouldAllowNegativePoints) { oldValue, newValue in
                            print("⌚️ Watch Settings: shouldAllowNegativePoints changed from \(oldValue) to \(newValue)")
                            let preferences: [String: Any] = [
                                "shouldAllowNegativePoints": newValue
                            ]
                            watchSyncCoordinator?.sendPreferences(preferences)
                        }
                    Toggle("Intervals", isOn: $hasEnabledIntervals)
                        .onChange(of: hasEnabledIntervals) { oldValue, newValue in
                            print("⌚️ Watch Settings: hasEnabledIntervals changed from \(oldValue) to \(newValue)")
                            let preferences: [String: Any] = [
                                "hasEnabledIntervals": newValue
                            ]
                            watchSyncCoordinator?.sendPreferences(preferences)
                        }
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

                // Teams section
                Section("Teams") {
                    ForEach(teams) { team in
                        NavigationLink(destination: EditTeamView(team: team)) {
                            HStack {
                                Circle()
                                    .fill(team.resolvedColor)
                                    .frame(width: 12, height: 12)
                                Text(team.name)
                            }
                        }
                    }
                    .onDelete(perform: deleteTeams)

                    Button {
                        addTeam()
                    } label: {
                        Label("Add Team", systemImage: "plus.circle.fill")
                    }
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
        do {
            try modelContext.save()
            // Send data to iPhone after save completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                watchSyncCoordinator?.sendTeamDataToPhone()
            }
        } catch {
            print("⌚️ Watch Settings: Failed to save after reset: \(error)")
        }
    }

    private func reinitializeApp() {
        teams.forEach { modelContext.delete($0) }
        intervals.forEach { modelContext.delete($0) }
        Team.createBaseData(modelContext: modelContext)
        do {
            try modelContext.save()
            print("⌚️ Watch Settings: Reinitialized, sending data to iPhone...")
            // Send data to iPhone after save completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                watchSyncCoordinator?.sendTeamDataToPhone()
            }
        } catch {
            print("⌚️ Watch Settings: Failed to save after reinitialize: \(error)")
        }
    }

    private func addTeam() {
        let team = Team(name: "Team \(teams.count + 1)")
        modelContext.insert(team)
        do {
            try modelContext.save()
            print("⌚️ Watch Settings: Added team '\(team.name)', sending data to iPhone...")
            // Send data to iPhone after save completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                watchSyncCoordinator?.sendTeamDataToPhone()
            }
        } catch {
            print("⌚️ Watch Settings: Failed to save after adding team: \(error)")
        }
    }

    private func deleteTeams(at offsets: IndexSet) {
        // Ensure at least 2 teams remain
        guard teams.count - offsets.count >= 2 else {
            print("⌚️ Watch Settings: Cannot delete team - must have at least 2 teams")
            return
        }

        for index in offsets {
            let team = teams[index]
            print("⌚️ Watch Settings: Deleting team '\(team.name)'")
            modelContext.delete(team)
        }

        do {
            try modelContext.save()
            print("⌚️ Watch Settings: Deleted teams, sending data to iPhone...")
            // Send data to iPhone after save completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                watchSyncCoordinator?.sendTeamDataToPhone()
            }
        } catch {
            print("⌚️ Watch Settings: Failed to save after deleting teams: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Team.self, Interval.self], inMemory: true)
}
