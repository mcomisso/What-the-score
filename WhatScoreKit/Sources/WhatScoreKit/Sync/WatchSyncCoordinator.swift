import Foundation
import SwiftData
import OSLog

#if canImport(WatchConnectivity)

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "WatchSync")

/// Coordinates data synchronization between iOS and watchOS using structured services
/// @deprecated Use iOSWatchSyncCoordinator for iOS or WatchOSWatchSyncCoordinator for watchOS instead
@available(*, deprecated, message: "Use iOSWatchSyncCoordinator for iOS or WatchOSWatchSyncCoordinator for watchOS instead")
@MainActor
@Observable
public final class WatchSyncCoordinator {

    private let modelContainer: ModelContainer
    private var syncService: any DataSyncService
    private let conversionService: any DataConversionService
    private let isWatch: Bool

    public init(
        modelContainer: ModelContainer,
        syncService: (any DataSyncService)? = nil,
        conversionService: (any DataConversionService)? = nil
    ) {
        self.modelContainer = modelContainer
        self.syncService = syncService ?? WatchConnectivityDataSyncService()
        self.conversionService = conversionService ?? SwiftDataConversionService()

        #if os(watchOS)
        self.isWatch = true
        #else
        self.isWatch = false
        #endif

        setupCallbacks()
        logger.info("WatchSyncCoordinator initialized")
    }

    // MARK: - Setup

    private func setupCallbacks() {
        if isWatch {
            // Watch waits to receive data from iPhone (iPhone is source of truth)
            syncService.onSessionActivated = {
                logger.info("Session activated, waiting to receive data from iPhone")
            }
        } else {
            // Send initial data when session activates (iOS is source of truth)
            syncService.onSessionActivated = { [weak self] in
                logger.info("Session activated, sending initial data to watch")
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    self?.sendData()
                }
            }
        }

        // Handle data received from paired device
        syncService.onDataReceived = { [weak self] syncData in
            let source = self?.isWatch == true ? "iPhone" : "watch"
            logger.info("Received data from \(source): \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            self?.updateFromPairedDevice(syncData)
        }
    }

    // MARK: - Send Data

    /// Send current data to the paired device
    public func sendData() {
        let context = ModelContext(modelContainer)
        let destination = isWatch ? "iPhone" : "watch"

        do {
            let syncData = try conversionService.createSyncData(from: context)
            logger.info("Sending data to \(destination): \(syncData.teams.count) teams, \(syncData.intervals.count) intervals")
            syncService.sendData(syncData)
        } catch {
            logger.error("Failed to create sync data: \(error.localizedDescription)")
        }
    }

    // MARK: - Legacy method names for compatibility

    /// Send current data to the watch (iOS only)
    public func sendTeamDataToWatch() {
        sendData()
    }

    /// Send current data to the iPhone (watchOS only)
    public func sendTeamDataToPhone() {
        sendData()
    }

    // MARK: - Receive Data

    private func updateFromPairedDevice(_ syncData: SyncData) {
        let context = ModelContext(modelContainer)
        let source = isWatch ? "iPhone" : "watch"
        do {
            try conversionService.updateModels(with: syncData, in: context)
            logger.info("Successfully updated from \(source) data")
        } catch {
            logger.error("Failed to update from \(source): \(error.localizedDescription)")
        }
    }
}

#endif
