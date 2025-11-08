import Foundation
import OSLog

#if canImport(WatchConnectivity)

private let logger = Logger(subsystem: "com.mcomisso.ScoreMatching.WhatScoreKit", category: "WatchConnectivitySync")

/// Adapter for WatchConnectivityManager to conform to DataSyncService protocol
public final class WatchConnectivityDataSyncService: DataSyncService {

    private let connectivityManager: WatchConnectivityManager

    public var onDataReceived: ((SyncData) -> Void)?
    public var onSessionActivated: (() -> Void)? {
        didSet {
            // Update the connectivity manager's callback
            connectivityManager.onSessionActivated = onSessionActivated

            // If session is already activated, call the callback immediately
            if connectivityManager.isSessionActivated {
                logger.info("Session already activated, calling onSessionActivated immediately")
                print("⚡️ WatchConnectivity: Session already activated, triggering callback now")
                onSessionActivated?()
            }
        }
    }

    public init(connectivityManager: WatchConnectivityManager = .shared) {
        print("🔧 WatchConnectivityDataSyncService: init() called")
        print("🔧 WatchConnectivityDataSyncService: Getting WatchConnectivityManager.shared...")
        self.connectivityManager = connectivityManager
        print("🔧 WatchConnectivityDataSyncService: Setting up callbacks...")
        setupCallbacks()
        print("✅ WatchConnectivityDataSyncService: Initialization complete")
    }

    private func setupCallbacks() {
        // Set up data received callback
        connectivityManager.onDataReceived = { [weak self] teamsDict, intervalsDict in
            logger.info("Received data from paired device")
            print("📥 WatchConnectivityDataSyncService: Processing received data")

            // Build dictionary for SyncData parsing
            let dict: [String: Any] = [
                "teams": teamsDict,
                "intervals": intervalsDict
            ]

            guard let syncData = SyncData.from(dictionary: dict) else {
                logger.error("Failed to parse SyncData from received dictionary")
                print("❌ WatchConnectivityDataSyncService: Failed to parse SyncData")
                return
            }

            print("✅ WatchConnectivityDataSyncService: Parsed SyncData successfully, calling onDataReceived callback")
            self?.onDataReceived?(syncData)
        }
    }

    public func sendData(_ syncData: SyncData) {
        let dict = syncData.toDictionary()

        guard let teams = dict["teams"] as? [[String: Any]] else {
            logger.error("Invalid teams data in SyncData")
            return
        }

        let intervals = (dict["intervals"] as? [[String: Any]]) ?? []

        logger.info("Sending data: \(teams.count) teams, \(intervals.count) intervals")
        connectivityManager.sendTeamData(teams, intervals: intervals)
    }
}

#endif
