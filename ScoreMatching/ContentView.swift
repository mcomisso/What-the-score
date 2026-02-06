import SwiftUI
import SwiftData
import WhatScoreKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "ContentView")

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.modelContext) var modelContext
    @Environment(\.watchSyncCoordinator) var watchSyncCoordinator

    @AppStorage(AppStorageValues.hasEnabledIntervals)
    var hasEnabledIntervals: Bool = false

    @AppStorage(AppStorageValues.shouldAllowNegativePoints)
    var shouldAllowNegativePoints: Bool = false

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Query(sort: \Interval.date) var intervals: [Interval]

    @State private var lastTapped: String?

    @State private var isVisualisingSettings: Bool = false
    @State private var isShowingIntervals: Bool = false
    @State private var showingQuickIntervalPrompt: Bool = false
    @State private var quickIntervalName: String = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if verticalSizeClass == .regular {
                portraitButtons
            } else if verticalSizeClass == .compact {
                landscapeButtons
            }

            bottomToolbar
                .ignoresSafeArea(.all, edges: .all)
                .padding()
        }
        .sheet(isPresented: $isShowingIntervals) {
            IntervalsList()
                .presentationDetents([.medium])
                .onAppear {
                    Analytics.log(.intervalsViewed, with: ["interval_count": "\(intervals.count)"])
                }
        }
        .sheet(isPresented: $isVisualisingSettings, onDismiss: nil, content: {
            SettingsView()
                .onAppear {
                    Analytics.log(.settingsOpened, with: ["team_count": "\(teams.count)"])
                }
        })
        .alert("Name this interval", isPresented: $showingQuickIntervalPrompt) {
            TextField("e.g., Q1, Half 1", text: $quickIntervalName)
            Button("Cancel", role: .cancel) {
                quickIntervalName = ""
            }
            Button("Create") {
                createQuickInterval(name: quickIntervalName.isEmpty ? "Interval \(intervals.count + 1)" : quickIntervalName)
                quickIntervalName = ""
            }
        }
        .onChange(of: shouldAllowNegativePoints) { oldValue, newValue in
            // When negative points is disabled, remove all negative scores
            if !newValue {
                cleanupNegativeScores()
            }
        }
        .onAppear {
            if teams.isEmpty {
                Team.createBaseData(modelContext: modelContext)
            }
        }
        // WatchConnectivity sends team data changes to watch instantly
    }

    private func cleanupNegativeScores() {
        for team in teams {
            team.score.removeNegativeScores()
        }
    }

    private func createQuickInterval(name: String) {
        let interval = Interval.create(name: name, from: teams)
        modelContext.insert(interval)
        Analytics.log(.intervalCreated, with: ["interval_count": "\(intervals.count + 1)", "source": "quick_add"])

        // Immediately sync to watch after creating quick interval
        do {
            try modelContext.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                watchSyncCoordinator?.sendData()
            }
        } catch {
            logger.error("Failed to save after creating quick interval: \(error.localizedDescription)")
        }
    }

    var bottomToolbar: some View {
        HStack {
            if hasEnabledIntervals {
                Group {
                    if #available(iOS 26.0, *) {
                        Button("Timer", systemImage: "timer") {
                            withAnimation(Animation.interactiveSpring()) {
                                isShowingIntervals.toggle()
                            }
                        }
                        .labelStyle(.iconOnly)
                        .imageScale(.large)
                        .controlSize(.extraLarge)
                        .buttonBorderShape(.circle)
                        .buttonStyle(.glass)
                    } else {
                        Button {
                            withAnimation(Animation.interactiveSpring()) {
                                isShowingIntervals.toggle()
                            }
                        } label: {
                            Image(systemName: "timer")
                                .foregroundStyle(.primary)
                                .imageScale(.large)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .shadow(radius: 8)
                        }
                    }
                }
                .contextMenu {
                    Button {
                        showingQuickIntervalPrompt = true
                    } label: {
                        Label("Quick Add Interval", systemImage: "plus.circle")
                    }

                    Button {
                        createQuickInterval(name: "Q\(intervals.count + 1)")
                    } label: {
                        Label("Add Q\(intervals.count + 1)", systemImage: "clock")
                    }
                }
            }

            Spacer()

            Group {
                if #available(iOS 26.0, *) {
                    Button("Settings", systemImage: "gear") {
                        isVisualisingSettings.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .controlSize(.extraLarge)
                    .buttonBorderShape(.circle)
                    .imageScale(.large)
                    .buttonStyle(.glass)
                } else {
                    Button {
                        isVisualisingSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.primary)
                            .imageScale(.large)
                            .padding()
                            .background(.regularMaterial,
                                        in: RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 8)
                    }
                }
            }
            .contextMenu {
                Button {
                    resetScoresToZero()
                } label: {
                    Label("Set scores to 0", systemImage: "arrow.counterclockwise")
                }

                Divider()

                Button(role: .destructive) {
                    reinitializeApp()
                } label: {
                    Label("Reset all", systemImage: "trash")
                }
            }
        }.symbolRenderingMode(.hierarchical)
    }

    private func resetScoresToZero() {
        let totalScore = teams.reduce(0) { $0 + $1.score.totalScore }
        teams.forEach { $0.score = [] }
        Analytics.log(.scoresReset, with: ["team_count": "\(teams.count)", "total_score": "\(totalScore)", "source": "context_menu"])
        saveAndSync()
    }

    private func reinitializeApp() {
        Analytics.log(.appReinitialized, with: ["team_count": "\(teams.count)", "interval_count": "\(intervals.count)", "source": "context_menu"])
        teams.forEach { modelContext.delete($0) }
        Team.createBaseData(modelContext: modelContext)
        saveAndSync()
    }

    private func saveAndSync() {
        do {
            try modelContext.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                watchSyncCoordinator?.sendTeamDataToWatch()
            }
        } catch {
            logger.error("Failed to save: \(error.localizedDescription)")
        }
    }

    var buttons: some View {
        ForEach(teams) { team in
            @Bindable var bindingTeam = team
            TapButton(
                score: $bindingTeam.score,
                colorHex: $bindingTeam.color,
                name: $bindingTeam.name,
                lastTapped: $lastTapped,
                onScoreChanged: {
                    watchSyncCoordinator?.sendTeamDataToWatch()
                }
            )
            .background(Color(hex: team.color))
            .overlay(alignment: .leading) {
                if lastTapped == team.name {
                    Image(systemName: "arrowtriangle.right.fill")
                        .resizable()
                        .foregroundStyle(team.resolvedColor)
                        .frame(width: 32, height: 32)
                        .colorInvert()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.smooth, value: lastTapped)
        }
    }

    var landscapeButtons: some View {
        HStack(spacing: 0) {
            buttons
        }.ignoresSafeArea()
    }

    var portraitButtons: some View {
        VStack(spacing: 0) {
            buttons
        }.ignoresSafeArea()
    }

}


#Preview {
    ModelContainerPreview {
        ContentView()
    } modelContainer: {
        try makeModelContainer()
    }
}
