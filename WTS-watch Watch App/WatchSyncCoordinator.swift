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

        // Don't send initial data from watch - iPhone is the source of truth
        // Watch will receive data from iPhone and only send when user makes changes
        connectivityManager.onSessionActivated = { [weak self] in
            print("⌚️ Watch: Session activated, waiting to receive data from iPhone (iPhone is source of truth)")
            // Do NOT send data here - let iPhone send first
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
            print("⌚️ Watch: Sending \(teams.count) teams to iPhone")
        } catch {
            logger.error("Failed to fetch teams for sending: \(error.localizedDescription)")
        }
    }

    // MARK: - Receive Data from Phone

    private func updateTeamsFromPhone(_ teamsData: [[String: Any]]) {
        print("⌚️ Watch: Received \(teamsData.count) teams from iPhone, updating...")
        logger.info("Updating teams from iPhone data: \(teamsData.count) teams")

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])

        do {
            let existingTeams = try modelContext.fetch(descriptor)
            print("⌚️ Watch: Found \(existingTeams.count) existing teams locally")

            // Check if data is actually different before updating
            var needsUpdate = false
            if existingTeams.count != teamsData.count {
                needsUpdate = true
                print("⌚️ Watch: Team count mismatch - update needed")
            } else {
                // Check if any team data is different
                for (index, teamData) in teamsData.enumerated() {
                    guard index < existingTeams.count else { break }
                    let existingTeam = existingTeams[index]

                    if let name = teamData["name"] as? String, existingTeam.name != name {
                        needsUpdate = true
                        print("⌚️ Watch: Team name changed - update needed")
                        break
                    }
                    if let color = teamData["color"] as? String, existingTeam.color != color {
                        needsUpdate = true
                        print("⌚️ Watch: Team color changed from '\(existingTeam.color)' to '\(color)' - update needed")
                        break
                    }
                    if let scoreData = teamData["score"] as? [[String: Any]] {
                        if existingTeam.score.count != scoreData.count {
                            needsUpdate = true
                            print("⌚️ Watch: Score count changed from \(existingTeam.score.count) to \(scoreData.count) - update needed")
                            break
                        }
                    }
                }
            }

            if !needsUpdate {
                print("⌚️ Watch: No changes detected, skipping update to avoid ping-pong")
                return
            }

            // Handle team count changes
            if teamsData.count > existingTeams.count {
                // Add new teams
                print("⌚️ Watch: Adding \(teamsData.count - existingTeams.count) new teams")
                for index in existingTeams.count..<teamsData.count {
                    let teamData = teamsData[index]
                    guard let name = teamData["name"] as? String,
                          let color = teamData["color"] as? String else { continue }

                    let scores = extractScores(from: teamData)
                    let team = Team(score: scores, name: name, color: color)
                    modelContext.insert(team)
                    print("⌚️ Watch: ✅ Added new team '\(name)'")
                }
            } else if teamsData.count < existingTeams.count {
                // Remove excess teams
                print("⌚️ Watch: Removing \(existingTeams.count - teamsData.count) teams")
                for index in (teamsData.count..<existingTeams.count).reversed() {
                    modelContext.delete(existingTeams[index])
                }
            }

            // Update existing teams (preserving their identity/UUID)
            let teamsToUpdate = try modelContext.fetch(descriptor)
            for (index, teamData) in teamsData.enumerated() {
                guard index < teamsToUpdate.count else { break }

                guard let name = teamData["name"] as? String,
                      let color = teamData["color"] as? String else {
                    print("⌚️ Watch: ❌ Skipping team with missing name or color")
                    continue
                }

                let team = teamsToUpdate[index]
                team.name = name
                team.color = color
                team.score = extractScores(from: teamData)
                print("⌚️ Watch: ✅ Updated team '\(name)' with color '\(color)'")
            }

            try modelContext.save()

            // Force refresh by triggering a notification
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("TeamsDidUpdate"), object: nil)
            }

            logger.info("Successfully updated teams from iPhone")
            print("⌚️ Watch: Teams updated successfully, UI should refresh")
        } catch {
            logger.error("Failed to update teams from iPhone: \(error.localizedDescription)")
            print("⌚️ Watch: ERROR updating teams: \(error.localizedDescription)")
        }
    }

    private func extractScores(from teamData: [String: Any]) -> [Score] {
        guard let scoreData = teamData["score"] as? [[String: Any]] else {
            return []
        }
        return scoreData.compactMap { dict in
            guard let timeInterval = dict["time"] as? TimeInterval,
                  let value = dict["value"] as? Int else { return nil }
            return Score(time: Date(timeIntervalSince1970: timeInterval), value: value)
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
            // DO NOT send data back - iPhone already has this data and sent us the command
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
            // DO NOT send data back - iPhone already has this data and sent us the command
            logger.info("App reinitialized successfully")
        } catch {
            logger.error("Failed to reinitialize app: \(error.localizedDescription)")
        }
    }
}
