import SwiftUI
import WhatScoreKit
import StoreKit
#if canImport(WidgetKit)
import WidgetKit
#endif
import SwiftData
import OSLog

@main
struct ScoreMatchingApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("totalLaunches") var totalLaunches: Int = 1

    @Environment(\.requestReview) var requestReview
    @Environment(\.scenePhase) var scenePhase

    @AppStorage(AppStorageValues.shouldKeepScreenAwake)
    var shouldKeepScreenAwake: Bool = false

    @State private var watchSyncCoordinator: WatchSyncCoordinator
    private let modelContainer: ModelContainer

    init() {
        // Initialize model container with CloudKit for automatic sync across devices
        // CloudKit handles syncing between iOS and watchOS automatically
        do {
            let schema = Schema([Team.self, Interval.self, Game.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.mcomisso.ScoreMatching")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            watchSyncCoordinator = WatchSyncCoordinator(modelContainer: modelContainer)

            // Migrate any teams with empty colors
            migrateTeamColors()

            // Note: CloudKit sync happens automatically. WatchConnectivity is only used for
            // commands like reset and reinitialize that need immediate execution.
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    private func migrateTeamColors() {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Team>()

        do {
            let teams = try context.fetch(descriptor)
            var needsSave = false

            for team in teams {
                if team.color.isEmpty {
                    team.color = Color.random.toHex()
                    needsSave = true
                }
            }

            if needsSave {
                try context.save()
            }
        } catch {
            print("Failed to migrate team colors: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    requestReviewIfNeeded()
                    setAwakeState()
                }
                .onChange(of: scenePhase) { _, phase in
                    onSceneActive(phase)
                }
                .onChange(of: shouldKeepScreenAwake, initial: false) { _, newValue in
                    UIApplication.shared.isIdleTimerDisabled = newValue
                }
                .environment(watchSyncCoordinator)
        }
        .modelContainer(modelContainer)
    }

    private func setAwakeState() {
        UIApplication.shared.isIdleTimerDisabled = shouldKeepScreenAwake
    }

    private func onSceneActive(_ phase: ScenePhase) {
        guard phase == .active else {
            return
        }
        totalLaunches += 1

        // CloudKit automatically syncs data - no manual notification needed
    }

    private func requestReviewIfNeeded() {
        if totalLaunches % 3 == 0 {
            requestReview()
        }
    }
}

// Environment key for watch sync coordinator
private struct WatchSyncCoordinatorKey: EnvironmentKey {
    static let defaultValue: WatchSyncCoordinator? = nil
}

extension EnvironmentValues {
    var watchSyncCoordinator: WatchSyncCoordinator? {
        get { self[WatchSyncCoordinatorKey.self] }
        set { self[WatchSyncCoordinatorKey.self] = newValue }
    }
}

// MARK: - WatchSyncCoordinator

private let watchSyncLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "WatchSync")

/// Coordinates data and commands between iOS and watchOS
/// WatchConnectivity handles immediate data transfer, CloudKit provides backup sync
@Observable
final class WatchSyncCoordinator {

    private let modelContext: ModelContext
    private let modelContainer: ModelContainer
    private let connectivityManager = WatchConnectivityManager.shared

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        setupCallbacks()
        watchSyncLogger.info("WatchSyncCoordinator initialized")

        // Send initial team data when session activates
        connectivityManager.onSessionActivated = { [weak self] in
            self?.sendTeamDataToWatch()
        }
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Handle reset scores command from watch
        connectivityManager.onResetScores = { [weak self] in
            self?.resetScores()
        }

        // Handle reinitialize command from watch
        connectivityManager.onReinitializeApp = { [weak self] in
            self?.reinitializeApp()
        }

        // Handle team data received from watch
        connectivityManager.onTeamDataReceived = { [weak self] teamsData in
            self?.updateTeamsFromWatch(teamsData)
        }
    }

    // MARK: - Send Data to Watch

    /// Send current team data to the watch
    public func sendTeamDataToWatch() {
        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let teams = try modelContext.fetch(descriptor)
            let teamsData = teams.map { team -> [String: Any] in
                [
                    "name": team.name,
                    "color": team.color,
                    "score": team.score.map { ["time": $0.time.timeIntervalSince1970, "value": $0.value] }
                ]
            }
            connectivityManager.sendTeamData(teamsData)
            watchSyncLogger.info("Sent team data to watch: \(teams.count) teams")
        } catch {
            watchSyncLogger.error("Failed to fetch teams for sending: \(error.localizedDescription)")
        }
    }

    // MARK: - Receive Data from Watch

    private func updateTeamsFromWatch(_ teamsData: [[String: Any]]) {
        watchSyncLogger.info("Updating teams from watch data: \(teamsData.count) teams")

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let existingTeams = try modelContext.fetch(descriptor)

            // Update existing teams with data from watch
            for (index, teamData) in teamsData.enumerated() {
                guard index < existingTeams.count else { break }

                let team = existingTeams[index]

                if let name = teamData["name"] as? String {
                    team.name = name
                }
                if let color = teamData["color"] as? String {
                    team.color = color
                }
                if let scoreData = teamData["score"] as? [[String: Any]] {
                    team.score = scoreData.compactMap { dict in
                        guard let timeInterval = dict["time"] as? TimeInterval,
                              let value = dict["value"] as? Int else { return nil }
                        return Score(time: Date(timeIntervalSince1970: timeInterval), value: value)
                    }
                }
            }

            try modelContext.save()
            watchSyncLogger.info("Successfully updated teams from watch")
        } catch {
            watchSyncLogger.error("Failed to update teams from watch: \(error.localizedDescription)")
        }
    }

    // MARK: - Handle Commands from Watch

    private func resetScores() {
        watchSyncLogger.info("Resetting scores from watch command")

        let descriptor = FetchDescriptor<Team>()

        do {
            let teams = try modelContext.fetch(descriptor)
            teams.forEach { $0.score = [] }
            try modelContext.save()
            sendTeamDataToWatch()
            watchSyncLogger.info("Scores reset successfully")
        } catch {
            watchSyncLogger.error("Failed to reset scores: \(error.localizedDescription)")
        }
    }

    private func reinitializeApp() {
        watchSyncLogger.info("Reinitializing app from watch command")

        let teamDescriptor = FetchDescriptor<Team>()
        let intervalDescriptor = FetchDescriptor<Interval>()

        do {
            let teams = try modelContext.fetch(teamDescriptor)
            let intervals = try modelContext.fetch(intervalDescriptor)

            teams.forEach { modelContext.delete($0) }
            intervals.forEach { modelContext.delete($0) }

            Team.createBaseData(modelContext: modelContext)
            try modelContext.save()
            sendTeamDataToWatch()

            watchSyncLogger.info("App reinitialized successfully")
        } catch {
            watchSyncLogger.error("Failed to reinitialize app: \(error.localizedDescription)")
        }
    }
}
