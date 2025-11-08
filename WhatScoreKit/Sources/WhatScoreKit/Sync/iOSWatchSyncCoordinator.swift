import Foundation
import SwiftData
import OSLog

#if canImport(UIKit)
import UIKit
#endif

private let logger = Logger(subsystem: "com.mcomisso.ScoreMatching.WhatScoreKit", category: "iOSWatchSync")

/// iOS-specific Watch Sync Coordinator
/// Responsibility: Send data to Apple Watch (iPhone is source of truth)
@MainActor
@Observable
public final class iOSWatchSyncCoordinator: WatchSyncCoordinatorProtocol {

    private let modelContainer: ModelContainer
    private var syncService: any DataSyncService
    private let conversionService: any DataConversionService

    public init(
        modelContainer: ModelContainer,
        syncService: (any DataSyncService)? = nil,
        conversionService: (any DataConversionService)? = nil
    ) {
        print("📱 iOSWatchSyncCoordinator: init() called")
        self.modelContainer = modelContainer
        print("📱 iOSWatchSyncCoordinator: Creating WatchConnectivityDataSyncService...")
        self.syncService = syncService ?? WatchConnectivityDataSyncService()
        print("📱 iOSWatchSyncCoordinator: Creating SwiftDataConversionService...")
        self.conversionService = conversionService ?? SwiftDataConversionService()

        print("📱 iOSWatchSyncCoordinator: About to setup callbacks...")
        setupCallbacks()
        logger.info("iOS Watch Sync Coordinator initialized")
        print("✅ iOSWatchSyncCoordinator: Initialization complete")
    }

    // MARK: - Setup

    private func setupCallbacks() {
        print("📱 iOSWatchSyncCoordinator: Setting up callbacks")

        // Send initial data when session activates (iOS is source of truth)
        syncService.onSessionActivated = { [weak self] in
            logger.info("WatchConnectivity session activated, sending initial data to Apple Watch")
            print("🔔 iOSWatchSyncCoordinator: onSessionActivated callback triggered!")
            Task { @MainActor [weak self] in
                // Small delay to ensure session is fully ready
                print("⏳ iOSWatchSyncCoordinator: Waiting 1 second before initial sync...")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                print("📤 iOSWatchSyncCoordinator: Sending initial data now...")
                await self?.sendData()
            }
        }

        // Handle data received from Apple Watch (bidirectional sync)
        syncService.onDataReceived = { [weak self] syncData in
            logger.info("Received data from Apple Watch: \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            print("📥 iOSWatchSyncCoordinator: Received data from Watch - \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")

            Task { @MainActor [weak self] in
                self?.updateFromWatch(syncData)
            }
        }

        // Handle preferences received from Apple Watch
        syncService.onPreferencesReceived = { [weak self] preferences in
            logger.info("Received preferences from Apple Watch: \(preferences.keys)")
            print("📥 iOSWatchSyncCoordinator: Received preferences from Watch - \(preferences.keys)")

            Task { @MainActor [weak self] in
                self?.updatePreferences(preferences)
            }
        }

        print("✅ iOSWatchSyncCoordinator: Callbacks setup complete")
    }

    // MARK: - Send Data to Watch

    /// Send current iPhone data to Apple Watch
    public func sendData() {
        print("🚀 iOSWatchSyncCoordinator: sendData() called")
        let context = ModelContext(modelContainer)

        do {
            let syncData = try conversionService.createSyncData(from: context)
            logger.info("Sending data to Apple Watch: \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            print("📊 iOSWatchSyncCoordinator: Created SyncData - \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            print("📤 iOSWatchSyncCoordinator: Calling syncService.sendData()...")
            syncService.sendData(syncData)
            print("✅ iOSWatchSyncCoordinator: syncService.sendData() completed")
        } catch {
            logger.error("Failed to create sync data for Apple Watch: \(error.localizedDescription)")
            print("❌ iOSWatchSyncCoordinator: Failed to create sync data - \(error.localizedDescription)")
        }
    }

    /// Legacy method for compatibility - sends data to watch
    public func sendTeamDataToWatch() {
        sendData()
    }

    // MARK: - Receive Data from Watch

    private func updateFromWatch(_ syncData: SyncData) {
        let context = ModelContext(modelContainer)

        do {
            try conversionService.updateModels(with: syncData, in: context)
            logger.info("Successfully updated iPhone data from Apple Watch")
        } catch {
            logger.error("Failed to update from Apple Watch: \(error.localizedDescription)")
        }
    }

    // MARK: - Preferences Sync

    /// Send preferences to Apple Watch
    public func sendPreferences(_ preferences: [String: Any]) {
        print("📤 iOSWatchSyncCoordinator: Sending preferences to Watch - \(preferences.keys)")
        logger.info("Sending preferences to Apple Watch: \(preferences.keys)")
        syncService.sendPreferences(preferences)
    }

    /// Update local preferences from Apple Watch
    private func updatePreferences(_ preferences: [String: Any]) {
        print("🔄 iOSWatchSyncCoordinator: Updating local preferences from Watch")
        logger.info("Updating preferences from Apple Watch: \(preferences.keys)")

        // Update UserDefaults with received preferences
        for (key, value) in preferences {
            UserDefaults.standard.set(value, forKey: key)
            print("📝 iOSWatchSyncCoordinator: Updated preference '\(key)' = \(value)")
        }

        // Synchronize to ensure changes are persisted immediately
        UserDefaults.standard.synchronize()

        // Post notification to trigger @AppStorage updates
        #if canImport(UIKit)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
        #endif

        logger.info("Successfully updated preferences from Apple Watch")
    }
}
