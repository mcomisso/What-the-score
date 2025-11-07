import SwiftUI
import WhatScoreKit
import StoreKit
#if canImport(WidgetKit)
import WidgetKit
#endif
import SwiftData

@main
struct ScoreMatchingApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @AppStorage("totalLaunches") var totalLaunches: Int = 1

    @Environment(\.requestReview) var requestReview
    @Environment(\.scenePhase) var scenePhase

    @AppStorage(AppStorageValues.shouldKeepScreenAwake)
    var shouldKeepScreenAwake: Bool = false

    @State private var watchSyncCoordinator: WatchSyncCoordinator?

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
                .environment(\.watchSyncCoordinator, watchSyncCoordinator)
        }
        .modelContainer(for: [Team.self, Interval.self, Game.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, watchSyncCoordinator == nil {
                initializeWatchSync()
            }
        }
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
        watchSyncCoordinator?.syncTeamsToWatch()
        watchSyncCoordinator?.syncIntervalsToWatch()
        watchSyncCoordinator?.syncSettingsToWatch()
    }

    private func requestReviewIfNeeded() {
        if totalLaunches % 3 == 0 {
            requestReview()
        }
    }

    private func initializeWatchSync() {
        guard let modelContainer = try? ModelContainer(for: Team.self, Interval.self, Game.self) else {
            return
        }
        let coordinator = WatchSyncCoordinator(modelContext: modelContainer.mainContext)
        watchSyncCoordinator = coordinator

        // Initial sync to watch
        coordinator.syncTeamsToWatch()
        coordinator.syncIntervalsToWatch()
        coordinator.syncSettingsToWatch()
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
