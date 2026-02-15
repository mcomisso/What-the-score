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
                scores: team.score.map { ScoreData(time: $0.time, value: $0.value) },
                creationDate: team.creationDate
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

        var unmatchedExisting = existingTeams

        for teamData in teamsData {
            if let matchedIndex = indexForMatchingTeam(teamData, in: unmatchedExisting) {
                let team = unmatchedExisting.remove(at: matchedIndex)
                applyTeamData(teamData, to: team)
                logger.info("Updated team: \(teamData.name)")
            } else {
                let scores = teamData.scores.map { Score(time: $0.time, value: $0.value) }
                let team = Team(score: scores, name: teamData.name, color: teamData.color)
                if let creationDate = teamData.creationDate {
                    team.creationDate = creationDate
                }
                context.insert(team)
                logger.info("Added new team: \(teamData.name)")
            }
        }

        for team in unmatchedExisting {
            context.delete(team)
            logger.info("Removed team: \(team.name)")
        }
    }

    private func needsUpdate(teamsData: [TeamData], existingTeams: [Team]) -> Bool {
        if existingTeams.count != teamsData.count {
            return true
        }

        let incomingSignatures = teamsData.map(teamSignature).sorted()
        let existingSignatures = existingTeams.map(teamSignature).sorted()

        return incomingSignatures != existingSignatures
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

        var unmatchedExisting = existingIntervals

        for intervalData in intervalsData {
            if let matchedIndex = indexForMatchingInterval(intervalData, in: unmatchedExisting) {
                let interval = unmatchedExisting.remove(at: matchedIndex)
                interval.name = intervalData.name
                interval.date = intervalData.date
                interval.teamSnapshots = intervalData.teamSnapshots
                logger.info("Updated interval: \(intervalData.name)")
            } else {
                let interval = Interval(
                    name: intervalData.name,
                    teamSnapshots: intervalData.teamSnapshots,
                    date: intervalData.date
                )
                context.insert(interval)
                logger.info("Added new interval: \(intervalData.name)")
            }
        }

        for interval in unmatchedExisting {
            context.delete(interval)
            logger.info("Removed interval: \(interval.name)")
        }
    }

    private func needsUpdate(intervalsData: [IntervalData], existingIntervals: [Interval]) -> Bool {
        if existingIntervals.count != intervalsData.count {
            return true
        }

        let incomingSignatures = intervalsData.map(intervalSignature).sorted()
        let existingSignatures = existingIntervals.map(intervalSignature).sorted()

        return incomingSignatures != existingSignatures
    }

    // MARK: - Settings

    private func applySettings(_ settings: SettingsData) {
        UserDefaults.standard.set(settings.allowNegativePoints, forKey: "shouldAllowNegativePoints")
        UserDefaults.standard.set(settings.intervalsEnabled, forKey: "hasEnabledIntervals")
        logger.info("Applied settings: negative=\(settings.allowNegativePoints), intervals=\(settings.intervalsEnabled)")
    }

    // MARK: - Matching and Signatures

    private func applyTeamData(_ teamData: TeamData, to team: Team) {
        team.name = teamData.name
        team.color = teamData.color
        team.score = teamData.scores.map { Score(time: $0.time, value: $0.value) }
        if let creationDate = teamData.creationDate {
            team.creationDate = creationDate
        }
    }

    private func indexForMatchingTeam(_ teamData: TeamData, in teams: [Team]) -> Int? {
        if let creationDate = teamData.creationDate,
           let index = teams.firstIndex(where: { abs($0.creationDate.timeIntervalSince1970 - creationDate.timeIntervalSince1970) < 0.001 }) {
            return index
        }
        if let index = teams.firstIndex(where: { $0.name == teamData.name }) {
            return index
        }
        return nil
    }

    private func indexForMatchingInterval(_ intervalData: IntervalData, in intervals: [Interval]) -> Int? {
        if let index = intervals.firstIndex(where: {
            $0.name == intervalData.name &&
            abs($0.date.timeIntervalSince1970 - intervalData.date.timeIntervalSince1970) < 0.001
        }) {
            return index
        }
        if let index = intervals.firstIndex(where: { $0.name == intervalData.name }) {
            return index
        }
        return nil
    }

    private func teamSignature(_ teamData: TeamData) -> String {
        let scoreSignature = teamData.scores
            .map { "\($0.time.timeIntervalSince1970):\($0.value)" }
            .joined(separator: ",")
        return "\(teamData.name)|\(teamData.color)|\(scoreSignature)"
    }

    private func teamSignature(_ team: Team) -> String {
        let scoreSignature = team.score
            .map { "\($0.time.timeIntervalSince1970):\($0.value)" }
            .joined(separator: ",")
        return "\(team.name)|\(team.color)|\(scoreSignature)"
    }

    private func intervalSignature(_ intervalData: IntervalData) -> String {
        let snapshotSignature = intervalData.teamSnapshots
            .map { "\($0.teamName):\($0.teamColor):\($0.totalScore)" }
            .joined(separator: ",")
        return "\(intervalData.name)|\(intervalData.date.timeIntervalSince1970)|\(snapshotSignature)"
    }

    private func intervalSignature(_ interval: Interval) -> String {
        let snapshotSignature = interval.teamSnapshots
            .map { "\($0.teamName):\($0.teamColor):\($0.totalScore)" }
            .joined(separator: ",")
        return "\(interval.name)|\(interval.date.timeIntervalSince1970)|\(snapshotSignature)"
    }
}
