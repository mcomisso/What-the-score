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
    private let modelContainer: ModelContainer

    init() {
        // Initialize model container with CloudKit for automatic sync with iPhone
        // CloudKit handles syncing between watchOS and iOS automatically
        do {
            let schema = Schema([Team.self, Interval.self, Game.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.mcomisso.ScoreMatching")
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            // Migrate any teams with empty colors
            migrateTeamColors()
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
                .environment(\.watchSyncCoordinator, watchSyncCoordinator)
                .onAppear {
                    if watchSyncCoordinator == nil {
                        watchSyncCoordinator = WatchSyncCoordinator(modelContainer: modelContainer)
                        // Note: Initial notification will be sent when app becomes active (onChange)
                        // to ensure WCSession has time to activate
                    }
                }
        }
        .modelContainer(modelContainer)
        // CloudKit automatically syncs data changes - no manual notification needed
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
