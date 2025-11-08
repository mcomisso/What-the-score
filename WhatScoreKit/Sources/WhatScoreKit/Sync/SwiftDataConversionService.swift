import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.mcomisso.ScoreMatching.WhatScoreKit", category: "DataConversion")

/// Converts between SwiftData models and sync data structures
public final class SwiftDataConversionService: DataConversionService {

    public init() {}

    // MARK: - Convert TO SyncData

    public func createSyncData(from context: ModelContext) throws -> SyncData {
        let teamDescriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])
        let intervalDescriptor = FetchDescriptor<Interval>(sortBy: [SortDescriptor(\.date)])

        let teams = try context.fetch(teamDescriptor)
        let intervals = try context.fetch(intervalDescriptor)

        let teamData = teams.map { team in
            TeamData(
                name: team.name,
                color: team.color,
                scores: team.score.map { ScoreData(time: $0.time, value: $0.value) }
            )
        }

        let intervalData = intervals.map { interval in
            IntervalData(
                name: interval.name,
                date: interval.date,
                teamSnapshots: interval.teamSnapshots
            )
        }

        return SyncData(teams: teamData, intervals: intervalData)
    }

    // MARK: - Update FROM SyncData

    public func updateModels(with syncData: SyncData, in context: ModelContext) throws {
        try updateTeams(syncData.teams, in: context)
        try updateIntervals(syncData.intervals, in: context)

        if let settings = syncData.settings {
            applySettings(settings)
        }

        try context.save()
    }

    // MARK: - Teams

    private func updateTeams(_ teamsData: [TeamData], in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])
        let existingTeams = try context.fetch(descriptor)

        logger.info("Updating teams: received \(teamsData.count), existing \(existingTeams.count)")

        // Check if update is needed
        guard needsUpdate(teamsData: teamsData, existingTeams: existingTeams) else {
            logger.info("No team changes detected, skipping update")
            return
        }

        // Handle count changes
        if teamsData.count > existingTeams.count {
            // Add new teams
            for index in existingTeams.count..<teamsData.count {
                let teamData = teamsData[index]
                let scores = teamData.scores.map { Score(time: $0.time, value: $0.value) }
                let team = Team(score: scores, name: teamData.name, color: teamData.color)
                context.insert(team)
                logger.info("Added new team: \(teamData.name)")
            }
        } else if teamsData.count < existingTeams.count {
            // Remove excess teams
            for index in (teamsData.count..<existingTeams.count).reversed() {
                context.delete(existingTeams[index])
                logger.info("Removed team at index \(index)")
            }
        }

        // Update existing teams (preserving UUID)
        let teamsToUpdate = try context.fetch(descriptor)
        for (index, teamData) in teamsData.enumerated() where index < teamsToUpdate.count {
            let team = teamsToUpdate[index]
            team.name = teamData.name
            team.color = teamData.color
            team.score = teamData.scores.map { Score(time: $0.time, value: $0.value) }
            logger.info("Updated team: \(teamData.name)")
        }
    }

    private func needsUpdate(teamsData: [TeamData], existingTeams: [Team]) -> Bool {
        if existingTeams.count != teamsData.count {
            return true
        }

        for (index, teamData) in teamsData.enumerated() where index < existingTeams.count {
            let existingTeam = existingTeams[index]
            if existingTeam.name != teamData.name ||
               existingTeam.color != teamData.color ||
               existingTeam.score.count != teamData.scores.count {
                return true
            }
        }

        return false
    }

    // MARK: - Intervals

    private func updateIntervals(_ intervalsData: [IntervalData], in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Interval>(sortBy: [SortDescriptor(\.date)])
        let existingIntervals = try context.fetch(descriptor)

        logger.info("Updating intervals: received \(intervalsData.count), existing \(existingIntervals.count)")

        // Check if update is needed
        guard needsUpdate(intervalsData: intervalsData, existingIntervals: existingIntervals) else {
            logger.info("No interval changes detected, skipping update")
            return
        }

        // Handle count changes
        if intervalsData.count > existingIntervals.count {
            // Add new intervals
            for index in existingIntervals.count..<intervalsData.count {
                let intervalData = intervalsData[index]
                let interval = Interval(
                    name: intervalData.name,
                    teamSnapshots: intervalData.teamSnapshots,
                    date: intervalData.date
                )
                context.insert(interval)
                logger.info("Added new interval: \(intervalData.name)")
            }
        } else if intervalsData.count < existingIntervals.count {
            // Remove excess intervals
            for index in (intervalsData.count..<existingIntervals.count).reversed() {
                context.delete(existingIntervals[index])
                logger.info("Removed interval at index \(index)")
            }
        }

        // Update existing intervals (preserving UUID)
        let intervalsToUpdate = try context.fetch(descriptor)
        for (index, intervalData) in intervalsData.enumerated() where index < intervalsToUpdate.count {
            let interval = intervalsToUpdate[index]
            interval.name = intervalData.name
            interval.date = intervalData.date
            interval.teamSnapshots = intervalData.teamSnapshots
            logger.info("Updated interval: \(intervalData.name)")
        }
    }

    private func needsUpdate(intervalsData: [IntervalData], existingIntervals: [Interval]) -> Bool {
        if existingIntervals.count != intervalsData.count {
            return true
        }

        for (index, intervalData) in intervalsData.enumerated() where index < existingIntervals.count {
            let existingInterval = existingIntervals[index]
            if existingInterval.name != intervalData.name {
                return true
            }
        }

        return false
    }

    // MARK: - Settings

    private func applySettings(_ settings: SettingsData) {
        UserDefaults.standard.set(settings.allowNegativePoints, forKey: "shouldAllowNegativePoints")
        UserDefaults.standard.set(settings.intervalsEnabled, forKey: "hasEnabledIntervals")
        logger.info("Applied settings: negative=\(settings.allowNegativePoints), intervals=\(settings.intervalsEnabled)")
    }
}
