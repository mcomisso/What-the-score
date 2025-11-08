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

    @State private var watchSyncCoordinator: iOSWatchSyncCoordinator
    private let modelContainer: ModelContainer

    init() {
        // Initialize model container with CloudKit for automatic sync across devices
        // CloudKit handles syncing between iOS and watchOS automatically
        do {
            let schema = Schema([Team.self, Interval.self, Game.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier("group.mcsoftware.whatTheScore"),
                cloudKitDatabase: .private("iCloud.com.mcomisso.ScoreMatching")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            watchSyncCoordinator = iOSWatchSyncCoordinator(modelContainer: modelContainer, syncService: nil, conversionService: nil)

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
    static let defaultValue: iOSWatchSyncCoordinator? = nil
}

extension EnvironmentValues {
    var watchSyncCoordinator: iOSWatchSyncCoordinator? {
        get { self[WatchSyncCoordinatorKey.self] }
        set { self[WatchSyncCoordinatorKey.self] = newValue }
    }
}
