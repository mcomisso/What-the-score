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
        // Initialize model container once with App Group for widget sharing
        do {
            let schema = Schema([Team.self, Interval.self, Game.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier("group.mcsoftware.whatTheScore")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            watchSyncCoordinator = WatchSyncCoordinator(modelContainer: modelContainer)

            // Initial sync to watch
            watchSyncCoordinator.syncTeamsToWatch()
            watchSyncCoordinator.syncIntervalsToWatch()
            watchSyncCoordinator.syncSettingsToWatch()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
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

        // Sync to watch when app becomes active
        watchSyncCoordinator.syncTeamsToWatch()
        watchSyncCoordinator.syncIntervalsToWatch()
        watchSyncCoordinator.syncSettingsToWatch()
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

/// Coordinates syncing between iOS SwiftData and Watch Connectivity
@Observable
final class WatchSyncCoordinator {

    private let modelContext: ModelContext
    private let connectivityManager = WatchConnectivityManager.shared

    init(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
        setupCallbacks()
        watchSyncLogger.info("WatchSyncCoordinator initialized")
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Handle teams received from watch
        connectivityManager.onTeamsReceived = { [weak self] teams in
            self?.updateTeamsFromWatch(teams)
        }

        // Handle intervals received from watch
        connectivityManager.onIntervalsReceived = { [weak self] intervals in
            self?.updateIntervalsFromWatch(intervals)
        }

        // Handle settings received from watch
        connectivityManager.onSettingsReceived = { [weak self] settings in
            self?.updateSettingsFromWatch(settings)
        }

        // Handle reset scores command from watch
        connectivityManager.onResetScores = { [weak self] in
            self?.resetScores()
        }

        // Handle reinitialize command from watch
        connectivityManager.onReinitializeApp = { [weak self] in
            self?.reinitializeApp()
        }
    }

    // MARK: - Send to Watch

    /// Send current teams to watch
    func syncTeamsToWatch() {
        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let teams = try modelContext.fetch(descriptor)
            let codableTeams = teams.map { $0.toCodable() }
            connectivityManager.sendTeams(codableTeams)
            watchSyncLogger.info("Synced \(teams.count) teams to watch")
        } catch {
            watchSyncLogger.error("Failed to fetch teams for sync: \(error.localizedDescription)")
        }
    }

    /// Send current intervals to watch
    func syncIntervalsToWatch() {
        let descriptor = FetchDescriptor<Interval>(sortBy: [SortDescriptor(\.date)])

        do {
            let intervals = try modelContext.fetch(descriptor)
            let codableIntervals = intervals.map { $0.toCodable() }
            connectivityManager.sendIntervals(codableIntervals)
            watchSyncLogger.info("Synced \(intervals.count) intervals to watch")
        } catch {
            watchSyncLogger.error("Failed to fetch intervals for sync: \(error.localizedDescription)")
        }
    }

    /// Send current settings to watch
    func syncSettingsToWatch() {
        let settings: [String: Any] = [
            "shouldAllowNegativePoints": UserDefaults.standard.bool(forKey: AppStorageValues.shouldAllowNegativePoints),
            "hasEnabledIntervals": UserDefaults.standard.bool(forKey: AppStorageValues.hasEnabledIntervals),
            "shouldKeepScreenAwake": UserDefaults.standard.bool(forKey: AppStorageValues.shouldKeepScreenAwake)
        ]
        connectivityManager.sendSettings(settings)
        watchSyncLogger.info("Synced settings to watch")
    }

    // MARK: - Receive from Watch

    private func updateTeamsFromWatch(_ codableTeams: [CodableTeamData]) {
        watchSyncLogger.info("Updating teams from watch: \(codableTeams.count)")

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let existingTeams = try modelContext.fetch(descriptor)

            // Create a map of existing teams by name for quick lookup
            var teamMap: [String: Team] = [:]
            for team in existingTeams {
                teamMap[team.name] = team
            }

            // Update or create teams from watch data
            for codableTeam in codableTeams {
                if let existingTeam = teamMap[codableTeam.name] {
                    // Update existing team
                    existingTeam.score = codableTeam.score
                    existingTeam.color = codableTeam.color.toHex()
                } else {
                    // Create new team
                    let newTeam = codableTeam.toTeam()
                    modelContext.insert(newTeam)
                }
            }

            try modelContext.save()
            watchSyncLogger.info("Successfully updated teams from watch")
        } catch {
            watchSyncLogger.error("Failed to update teams from watch: \(error.localizedDescription)")
        }
    }

    private func updateIntervalsFromWatch(_ codableIntervals: [CodableIntervalData]) {
        watchSyncLogger.info("Updating intervals from watch: \(codableIntervals.count)")

        let descriptor = FetchDescriptor<Interval>(sortBy: [SortDescriptor(\.date)])

        do {
            let existingIntervals = try modelContext.fetch(descriptor)

            // Check if we need to add new intervals
            if codableIntervals.count > existingIntervals.count {
                for codableInterval in codableIntervals.suffix(codableIntervals.count - existingIntervals.count) {
                    let newInterval = Interval.from(codable: codableInterval)
                    modelContext.insert(newInterval)
                }
                try modelContext.save()
                watchSyncLogger.info("Added \(codableIntervals.count - existingIntervals.count) new intervals from watch")
            }
        } catch {
            watchSyncLogger.error("Failed to update intervals from watch: \(error.localizedDescription)")
        }
    }

    private func updateSettingsFromWatch(_ settings: [String: Any]) {
        watchSyncLogger.info("Updating settings from watch")

        if let negativePoints = settings["shouldAllowNegativePoints"] as? Bool {
            UserDefaults.standard.set(negativePoints, forKey: AppStorageValues.shouldAllowNegativePoints)
        }

        if let intervals = settings["hasEnabledIntervals"] as? Bool {
            UserDefaults.standard.set(intervals, forKey: AppStorageValues.hasEnabledIntervals)
        }

        if let keepAwake = settings["shouldKeepScreenAwake"] as? Bool {
            UserDefaults.standard.set(keepAwake, forKey: AppStorageValues.shouldKeepScreenAwake)
        }
    }

    private func resetScores() {
        watchSyncLogger.info("Resetting scores from watch command")

        let descriptor = FetchDescriptor<Team>()

        do {
            let teams = try modelContext.fetch(descriptor)
            teams.forEach { $0.score = [] }
            try modelContext.save()
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

            watchSyncLogger.info("App reinitialized successfully")
        } catch {
            watchSyncLogger.error("Failed to reinitialize app: \(error.localizedDescription)")
        }
    }
}
