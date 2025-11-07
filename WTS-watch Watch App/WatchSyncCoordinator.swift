import Foundation
import SwiftData
import SwiftUI
import OSLog
import WhatScoreKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching.watchkit", category: "WatchSync")

/// Coordinates notifications between watchOS and iOS (data synced via CloudKit)
@Observable
public final class WatchSyncCoordinator {

    private let modelContext: ModelContext
    private let connectivityManager = WatchConnectivityManager.shared

    public init(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
        setupCallbacks()
        logger.info("WatchSyncCoordinator initialized")
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Handle data changed notification from iPhone
        connectivityManager.onDataChanged = { [weak self] in
            // CloudKit will handle the actual sync, just log it
            logger.info("Received data changed notification from iPhone")
        }

        // Handle reset scores command from iPhone
        connectivityManager.onResetScores = { [weak self] in
            self?.resetScores()
        }

        // Handle reinitialize command from iPhone
        connectivityManager.onReinitializeApp = { [weak self] in
            self?.reinitializeApp()
        }
    }

    // MARK: - Notify iPhone

    /// Notify iPhone that data has changed (CloudKit handles actual sync)
    public func notifyDataChanged() {
        connectivityManager.sendDataChangedNotification()
        logger.info("Notified iPhone that data changed")
    }

    /// Send reset scores command to iPhone
    func sendResetScoresToPhone() {
        connectivityManager.sendResetScores()
        logger.info("Sent reset scores command to iPhone")
    }

    /// Send reinitialize command to iPhone
    func sendReinitializeToPhone() {
        connectivityManager.sendReinitializeApp()
        logger.info("Sent reinitialize command to iPhone")
    }

    // MARK: - Handle Commands from iPhone

    private func resetScores() {
        logger.info("Resetting scores from iPhone command")

        let descriptor = FetchDescriptor<Team>()

        do {
            let teams = try modelContext.fetch(descriptor)
            teams.forEach { $0.score = [] }
            try modelContext.save()
            logger.info("Scores reset successfully")
        } catch {
            logger.error("Failed to reset scores: \(error.localizedDescription)")
        }
    }

    private func reinitializeApp() {
        logger.info("Reinitializing app from iPhone command")

        let teamDescriptor = FetchDescriptor<Team>()
        let intervalDescriptor = FetchDescriptor<Interval>()

        do {
            let teams = try modelContext.fetch(teamDescriptor)
            let intervals = try modelContext.fetch(intervalDescriptor)

            teams.forEach { modelContext.delete($0) }
            intervals.forEach { modelContext.delete($0) }

            Team.createBaseData(modelContext: modelContext)
            try modelContext.save()

            logger.info("App reinitialized successfully")
        } catch {
            logger.error("Failed to reinitialize app: \(error.localizedDescription)")
        }
    }
}
