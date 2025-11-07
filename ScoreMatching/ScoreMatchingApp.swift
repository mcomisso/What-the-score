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
        // Initialize model container with App Group for widget sharing and CloudKit for device sync
        do {
            let schema = Schema([Team.self, Interval.self, Game.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier("group.mcsoftware.whatTheScore"),
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            watchSyncCoordinator = WatchSyncCoordinator(modelContainer: modelContainer)

            // Notify watch that we're ready
            watchSyncCoordinator.notifyDataChanged()
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

        // Notify watch that data may have changed
        watchSyncCoordinator.notifyDataChanged()
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

/// Coordinates notifications between iOS and watchOS (data synced via CloudKit)
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
        // Handle data changed notification from watch
        connectivityManager.onDataChanged = { [weak self] in
            // CloudKit will handle the actual sync, just log it
            watchSyncLogger.info("Received data changed notification from watch")
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

    // MARK: - Notify Watch

    /// Notify watch that data has changed (CloudKit handles actual sync)
    func notifyDataChanged() {
        connectivityManager.sendDataChangedNotification()
        watchSyncLogger.info("Notified watch that data changed")
    }

    // MARK: - Handle Commands from Watch

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
