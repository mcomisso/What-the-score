import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.mcomisso.ScoreMatching.WhatScoreKit", category: "WatchOSWatchSync")

/// watchOS-specific Watch Sync Coordinator
/// Responsibility: Receive data from iPhone and send changes back (iPhone is source of truth)
@MainActor
@Observable
public final class WatchOSWatchSyncCoordinator: WatchSyncCoordinatorProtocol {

    private let modelContainer: ModelContainer
    private var syncService: any DataSyncService
    private let conversionService: any DataConversionService

    public init(
        modelContainer: ModelContainer,
        syncService: (any DataSyncService)? = nil,
        conversionService: (any DataConversionService)? = nil
    ) {
        print("⌚️ WatchOSWatchSyncCoordinator: init() called")
        self.modelContainer = modelContainer
        print("⌚️ WatchOSWatchSyncCoordinator: Creating WatchConnectivityDataSyncService...")
        self.syncService = syncService ?? WatchConnectivityDataSyncService()
        print("⌚️ WatchOSWatchSyncCoordinator: Creating SwiftDataConversionService...")
        self.conversionService = conversionService ?? SwiftDataConversionService()

        print("⌚️ WatchOSWatchSyncCoordinator: About to setup callbacks...")
        setupCallbacks()
        logger.info("watchOS Watch Sync Coordinator initialized")
        print("✅ WatchOSWatchSyncCoordinator: Initialization complete")
    }

    // MARK: - Setup

    private func setupCallbacks() {
        print("⌚️ WatchOSWatchSyncCoordinator: Setting up callbacks")

        // Watch waits to receive data from iPhone (iPhone is source of truth)
        syncService.onSessionActivated = {
            logger.info("WatchConnectivity session activated, waiting to receive data from iPhone")
            print("🔔 WatchOSWatchSyncCoordinator: onSessionActivated callback triggered - waiting for iPhone data")
        }

        // Handle data received from iPhone
        syncService.onDataReceived = { [weak self] syncData in
            logger.info("Received data from iPhone: \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            print("📥 WatchOSWatchSyncCoordinator: Received data from iPhone - \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")

            Task { @MainActor [weak self] in
                self?.updateFromiPhone(syncData)
            }
        }

        print("✅ WatchOSWatchSyncCoordinator: Callbacks setup complete")
    }

    // MARK: - Send Data to iPhone

    /// Send current Apple Watch data to iPhone (for bidirectional sync)
    public func sendData() {
        let context = ModelContext(modelContainer)

        do {
            let syncData = try conversionService.createSyncData(from: context)
            logger.info("Sending data to iPhone: \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            syncService.sendData(syncData)
        } catch {
            logger.error("Failed to create sync data for iPhone: \(error.localizedDescription)")
        }
    }

    /// Legacy method for compatibility - sends data to iPhone
    public func sendTeamDataToPhone() {
        sendData()
    }

    // MARK: - Receive Data from iPhone

    private func updateFromiPhone(_ syncData: SyncData) {
        let context = ModelContext(modelContainer)

        do {
            try conversionService.updateModels(with: syncData, in: context)
            logger.info("Successfully updated Apple Watch data from iPhone")
        } catch {
            logger.error("Failed to update from iPhone: \(error.localizedDescription)")
        }
    }
}
