//
//  WTS_watchApp.swift
//  WTS-watch Watch App
//
//  Created by Matteo Comisso on 06/11/2025.
//

import SwiftUI
import SwiftData
import WhatScoreKit

@main
struct WTS_watch_Watch_AppApp: App {
    @Environment(\.scenePhase) var scenePhase
    @State private var watchSyncCoordinator: WatchSyncCoordinator?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.watchSyncCoordinator, watchSyncCoordinator)
        }
        .modelContainer(for: [Team.self, Interval.self, Game.self])
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if watchSyncCoordinator == nil {
                    initializeWatchSync()
                } else {
                    // Sync when app becomes active
                    watchSyncCoordinator?.syncTeamsToPhone()
                    watchSyncCoordinator?.syncIntervalsToPhone()
                }
            }
        }
    }

    private func initializeWatchSync() {
        guard let modelContainer = try? ModelContainer(for: Team.self, Interval.self, Game.self) else {
            return
        }
        let coordinator = WatchSyncCoordinator(modelContainer: modelContainer)
        watchSyncCoordinator = coordinator

        // Initial sync to iPhone
        coordinator.syncTeamsToPhone()
        coordinator.syncIntervalsToPhone()
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
