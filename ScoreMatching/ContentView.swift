import SwiftUI
import SwiftData
import WhatScoreKit
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "ContentView")

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.watchSyncCoordinator) var watchSyncCoordinator

    @AppStorage(AppStorageValues.hasEnabledIntervals)
    var hasEnabledIntervals: Bool = false

    @AppStorage(AppStorageValues.shouldAllowNegativePoints)
    var shouldAllowNegativePoints: Bool = false

    @AppStorage(SportStorageKeys.currentSelection)
    private var currentSportStorage = ""

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Query(sort: \Interval.date) var intervals: [Interval]

    @State private var lastTapped: String?

    @State private var isVisualisingSettings: Bool = false
    @State private var isShowingIntervals: Bool = false
    @State private var showingQuickIntervalPrompt: Bool = false
    @State private var quickIntervalName: String = ""
    @State private var intentRouter = ScoreboardIntentRouter.shared

    private var currentSport: SportSelection {
        SportSelection(storageValue: currentSportStorage) ?? SportSelection(preset: .custom)
    }

    var body: some View {
        GeometryReader { container in
            ZStack(alignment: .bottom) {
                ScoreboardTiles(
                    teams: teams,
                    lastTapped: $lastTapped,
                    scoreValues: currentSport.scoreValues,
                    bottomContentInset: container.safeAreaInsets.bottom + 80
                )
                .ignoresSafeArea()

                bottomToolbar
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
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
        .alert("Name this \(currentSport.intervalSingular)", isPresented: $showingQuickIntervalPrompt) {
            TextField(currentSport.intervalName(number: intervals.count + 1), text: $quickIntervalName)
            Button("Cancel", role: .cancel) {
                quickIntervalName = ""
            }
            Button("Create") {
                createQuickInterval(name: quickIntervalName.isEmpty ? currentSport.intervalName(number: intervals.count + 1) : quickIntervalName)
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
        .onChange(of: intentRouter.pendingOpenScoreboard, initial: true) { _, requested in
            guard requested else { return }
            isShowingIntervals = false
            isVisualisingSettings = false
            showingQuickIntervalPrompt = false
            intentRouter.consumeOpenScoreboardRequest()
        }
        // WatchConnectivity sends team data changes to watch instantly
    }

    private func cleanupNegativeScores() {
        var didChange = false
        for team in teams {
            let beforeCount = team.score.count
            team.score.removeNegativeScores()
            if team.score.count != beforeCount {
                didChange = true
            }
        }

        guard didChange else {
            return
        }

        do {
            try modelContext.save()
            watchSyncCoordinator?.sendTeamDataToWatch()
        } catch {
            logger.error("Failed to save after removing negative scores: \(error.localizedDescription)")
        }
    }

    private func createQuickInterval(name: String) {
        do {
            try ScoreboardActions.createInterval(name: name, enabled: hasEnabledIntervals, in: modelContext)
            Analytics.log(.intervalCreated, with: ["interval_count": "\(intervals.count + 1)", "source": "quick_add"])
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
                        Button(currentSport.intervalPlural, systemImage: "timer") {
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
                        Label("Quick add \(currentSport.intervalSingular)", systemImage: "plus.circle")
                    }

                    Button {
                        createQuickInterval(name: currentSport.intervalName(number: intervals.count + 1))
                    } label: {
                        Label("Add \(currentSport.intervalName(number: intervals.count + 1))", systemImage: "clock")
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
        intervals.forEach { modelContext.delete($0) }
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

}

private struct ScoreboardTiles: View {
    @Environment(\.watchSyncCoordinator) private var watchSyncCoordinator
    @ScaledMetric(relativeTo: .headline) private var minimumTileHeight: CGFloat = 160

    let teams: [Team]
    @Binding var lastTapped: String?
    let scoreValues: [Int]
    let bottomContentInset: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let columnCount = columns(for: geometry.size)
            let rowCount = (teams.count + columnCount - 1) / columnCount
            let scrollHeight = max(1, geometry.size.height - bottomContentInset)
            let rowHeight = max(minimumTileHeight, scrollHeight / CGFloat(max(rowCount, 1)))

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<rowCount, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(teamsForRow(row, columns: columnCount)) { team in
                                    tile(for: team)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: rowHeight)
                        }
                    }
                    .frame(minHeight: scrollHeight)
                }
                .frame(height: scrollHeight)
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .modifier(HideTopScrollEdgeEffect())

                HStack(spacing: 0) {
                    ForEach(teamsForRow(max(0, rowCount - 1), columns: columnCount)) { team in
                        Color(hex: team.color)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: bottomContentInset)
                .allowsHitTesting(false)
            }
        }
    }

    private func columns(for size: CGSize) -> Int {
        let canFitTwoUsableTiles = size.width / 2 >= 160
        if teams.count == 2 {
            return size.width > size.height && canFitTwoUsableTiles ? 2 : 1
        }
        return min(4, max(1, Int(size.width / 220)))
    }

    private func teamsForRow(_ row: Int, columns: Int) -> [Team] {
        let start = row * columns
        return Array(teams[start..<min(start + columns, teams.count)])
    }

    private func tile(for team: Team) -> some View {
        Group {
            @Bindable var bindingTeam = team
            TapButton(
                score: $bindingTeam.score,
                colorHex: $bindingTeam.color,
                name: $bindingTeam.name,
                lastTapped: $lastTapped,
                scoreValues: scoreValues,
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
}

private struct HideTopScrollEdgeEffect: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(for: .top)
        } else {
            content
        }
    }
}


#Preview {
    ModelContainerPreview {
        ContentView()
    } modelContainer: {
        try makeModelContainer()
    }
}
