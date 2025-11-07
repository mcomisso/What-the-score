import Foundation
import SwiftData
import SwiftUI
import OSLog
import WhatScoreKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching.watchkit", category: "WatchSync")

/// Coordinates syncing between watchOS SwiftData and Watch Connectivity
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
        // Handle teams received from iPhone
        connectivityManager.onTeamsReceived = { [weak self] teams in
            self?.updateTeamsFromPhone(teams)
        }

        // Handle intervals received from iPhone
        connectivityManager.onIntervalsReceived = { [weak self] intervals in
            self?.updateIntervalsFromPhone(intervals)
        }

        // Handle settings received from iPhone
        connectivityManager.onSettingsReceived = { [weak self] settings in
            self?.updateSettingsFromPhone(settings)
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

    // MARK: - Send to iPhone

    /// Send current teams to iPhone
    public func syncTeamsToPhone() {
        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let teams = try modelContext.fetch(descriptor)
            let codableTeams = teams.map { $0.toCodable() }
            connectivityManager.sendTeams(codableTeams)
            logger.info("Synced \(teams.count) teams to iPhone")
        } catch {
            logger.error("Failed to fetch teams for sync: \(error.localizedDescription)")
        }
    }

    /// Send current intervals to iPhone
    public func syncIntervalsToPhone() {
        let descriptor = FetchDescriptor<Interval>(sortBy: [SortDescriptor(\.date)])

        do {
            let intervals = try modelContext.fetch(descriptor)
            let codableIntervals = intervals.map { $0.toCodable() }
            connectivityManager.sendIntervals(codableIntervals)
            logger.info("Synced \(intervals.count) intervals to iPhone")
        } catch {
            logger.error("Failed to fetch intervals for sync: \(error.localizedDescription)")
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

    // MARK: - Receive from iPhone

    private func updateTeamsFromPhone(_ codableTeams: [CodableTeamData]) {
        logger.info("Updating teams from iPhone: \(codableTeams.count)")

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let existingTeams = try modelContext.fetch(descriptor)

            // Create a map of existing teams by name for quick lookup
            var teamMap: [String: Team] = [:]
            for team in existingTeams {
                teamMap[team.name] = team
            }

            // Update or create teams from iPhone data
            for codableTeam in codableTeams {
                if let existingTeam = teamMap[codableTeam.name] {
                    // Update existing team
                    existingTeam.score = codableTeam.score
                    existingTeam.color = codableTeam.color.toHex()
                } else {
                    // Create new team
                    let newTeam = codableTeam.toTeam()
                    modelContext.insert(newTeam)
                }
            }

            // Remove teams that no longer exist on iPhone
            let phoneTeamNames = Set(codableTeams.map { $0.name })
            for team in existingTeams {
                if !phoneTeamNames.contains(team.name) {
                    modelContext.delete(team)
                }
            }

            try modelContext.save()
            logger.info("Successfully updated teams from iPhone")
        } catch {
            logger.error("Failed to update teams from iPhone: \(error.localizedDescription)")
        }
    }

    private func updateIntervalsFromPhone(_ codableIntervals: [CodableIntervalData]) {
        logger.info("Updating intervals from iPhone: \(codableIntervals.count)")

        let descriptor = FetchDescriptor<Interval>(sortBy: [SortDescriptor(\.date)])

        do {
            let existingIntervals = try modelContext.fetch(descriptor)

            // Check if we need to add new intervals
            if codableIntervals.count > existingIntervals.count {
                for codableInterval in codableIntervals.suffix(codableIntervals.count - existingIntervals.count) {
                    let newInterval = Interval.from(codable: codableInterval)
                    modelContext.insert(newInterval)
                }
                try modelContext.save()
                logger.info("Added \(codableIntervals.count - existingIntervals.count) new intervals from iPhone")
            }
        } catch {
            logger.error("Failed to update intervals from iPhone: \(error.localizedDescription)")
        }
    }

    private func updateSettingsFromPhone(_ settings: [String: Any]) {
        logger.info("Updating settings from iPhone")

        if let negativePoints = settings["shouldAllowNegativePoints"] as? Bool {
            UserDefaults.standard.set(negativePoints, forKey: "shouldAllowNegativePoints")
        }

        if let intervals = settings["hasEnabledIntervals"] as? Bool {
            UserDefaults.standard.set(intervals, forKey: "hasEnabledIntervals")
        }
    }

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
