import Foundation
import SwiftData
import OSLog

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
        self.modelContainer = modelContainer
        self.syncService = syncService ?? WatchConnectivityDataSyncService()
        self.conversionService = conversionService ?? SwiftDataConversionService()

        setupCallbacks()
        logger.info("iOS Watch Sync Coordinator initialized")
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Send initial data when session activates (iOS is source of truth)
        syncService.onSessionActivated = { [weak self] in
            logger.info("WatchConnectivity session activated, sending initial data to Apple Watch")
            Task { @MainActor [weak self] in
                // Small delay to ensure session is fully ready
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await self?.sendData()
            }
        }

        // Handle data received from Apple Watch (bidirectional sync)
        syncService.onDataReceived = { [weak self] syncData in
            logger.info("Received data from Apple Watch: \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            self?.updateFromWatch(syncData)
        }
    }

    // MARK: - Send Data to Watch

    /// Send current iPhone data to Apple Watch
    public func sendData() {
        let context = ModelContext(modelContainer)

        do {
            let syncData = try conversionService.createSyncData(from: context)
            logger.info("Sending data to Apple Watch: \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            syncService.sendData(syncData)
        } catch {
            logger.error("Failed to create sync data for Apple Watch: \(error.localizedDescription)")
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
}
