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
        // Initialize model container with App Group for sync with iPhone
        do {
            let schema = Schema([Team.self, Interval.self, Game.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier("group.mcsoftware.whatTheScore"),
                cloudKitDatabase: .automatic
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.watchSyncCoordinator, watchSyncCoordinator)
                .onAppear {
                    if watchSyncCoordinator == nil {
                        watchSyncCoordinator = WatchSyncCoordinator(modelContainer: modelContainer)
                        watchSyncCoordinator?.notifyDataChanged()
                    }
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Notify iPhone when app becomes active
                watchSyncCoordinator?.notifyDataChanged()
            }
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
