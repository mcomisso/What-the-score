import Foundation
import SwiftData
import SwiftUI
import OSLog
import WhatScoreKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching.watchkit", category: "WatchSync")

/// Coordinates data and commands between watchOS and iOS
/// WatchConnectivity handles immediate data transfer, CloudKit provides backup sync
@Observable
public final class WatchSyncCoordinator {

    private let modelContext: ModelContext
    private let modelContainer: ModelContainer
    private let connectivityManager = WatchConnectivityManager.shared

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        setupCallbacks()
        logger.info("WatchSyncCoordinator initialized")

        // Send initial team data when session activates
        connectivityManager.onSessionActivated = { [weak self] in
            self?.sendTeamDataToPhone()
        }
    }

    // MARK: - Setup

    private func setupCallbacks() {
        // Handle reset scores command from iPhone
        connectivityManager.onResetScores = { [weak self] in
            self?.resetScores()
        }

        // Handle reinitialize command from iPhone
        connectivityManager.onReinitializeApp = { [weak self] in
            self?.reinitializeApp()
        }

        // Handle team data received from iPhone
        connectivityManager.onTeamDataReceived = { [weak self] teamsData in
            self?.updateTeamsFromPhone(teamsData)
        }
    }

    // MARK: - Send Data to Phone

    /// Send current team data to the iPhone
    public func sendTeamDataToPhone() {
        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let teams = try modelContext.fetch(descriptor)
            let teamsData = teams.map { team -> [String: Any] in
                [
                    "name": team.name,
                    "color": team.color,
                    "score": team.score.map { ["time": $0.time.timeIntervalSince1970, "value": $0.value] }
                ]
            }
            connectivityManager.sendTeamData(teamsData)
            logger.info("Sent team data to iPhone: \(teams.count) teams")
        } catch {
            logger.error("Failed to fetch teams for sending: \(error.localizedDescription)")
        }
    }

    // MARK: - Receive Data from Phone

    private func updateTeamsFromPhone(_ teamsData: [[String: Any]]) {
        logger.info("Updating teams from iPhone data: \(teamsData.count) teams")

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let existingTeams = try modelContext.fetch(descriptor)

            // Update existing teams with data from iPhone
            for (index, teamData) in teamsData.enumerated() {
                guard index < existingTeams.count else { break }

                let team = existingTeams[index]

                if let name = teamData["name"] as? String {
                    team.name = name
                }
                if let color = teamData["color"] as? String {
                    team.color = color
                }
                if let scoreData = teamData["score"] as? [[String: Any]] {
                    team.score = scoreData.compactMap { dict in
                        guard let timeInterval = dict["time"] as? TimeInterval,
                              let value = dict["value"] as? Int else { return nil }
                        return Score(time: Date(timeIntervalSince1970: timeInterval), value: value)
                    }
                }
            }

            try modelContext.save()
            logger.info("Successfully updated teams from iPhone")
        } catch {
            logger.error("Failed to update teams from iPhone: \(error.localizedDescription)")
        }
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
            sendTeamDataToPhone()
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
            sendTeamDataToPhone()

            logger.info("App reinitialized successfully")
        } catch {
            logger.error("Failed to reinitialize app: \(error.localizedDescription)")
        }
    }
}
