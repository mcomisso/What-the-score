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
            connectivityManager.onSessionActivated = onSessionActivated
        }
    }

    public init(connectivityManager: WatchConnectivityManager = .shared) {
        self.connectivityManager = connectivityManager
        setupCallbacks()
    }

    private func setupCallbacks() {
        connectivityManager.onDataReceived = { [weak self] teamsDict, intervalsDict in
            logger.info("Received data from paired device")

            // Build dictionary for SyncData parsing
            var dict: [String: Any] = [
                "teams": teamsDict,
                "intervals": intervalsDict
            ]

            guard let syncData = SyncData.from(dictionary: dict) else {
                logger.error("Failed to parse SyncData from received dictionary")
                return
            }

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
