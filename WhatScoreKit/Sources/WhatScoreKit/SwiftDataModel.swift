import Foundation
import SwiftData
import SwiftUI

// TODO: Game model is defined but not yet used. Part of intervals feature implementation.
// Once intervals feature is complete, this should group teams and intervals together for a full game session.
@Model
public class Game {
    var date: Date = Date.now
    @Relationship(deleteRule: .nullify, inverse: \Team.game) var teams: [Team]? = []
    @Relationship(deleteRule: .nullify, inverse: \Interval.game) var intervals: [Interval]? = []

    init(date: Date = .now, teams: [Team] = [], intervals: [Interval] = []) {
        self.date = date
        self.teams = teams
        self.intervals = intervals
    }
}

public struct Score: Codable {
    public var time: Date
    public var value: Int

    public init(time: Date, value: Int = 1) {
        self.time = time
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.time = try container.decode(Date.self, forKey: .time)
        self.value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 1
    }
}

extension Array where Element == Score {
    public var totalScore: Int {
        map(\.value).reduce(0, +)
    }

    // Returns total score, ensuring it never goes below zero
    public var safeTotalScore: Int {
        Swift.max(0, totalScore)
    }

    // Removes all negative score entries
    public mutating func removeNegativeScores() {
        self.removeAll { $0.value < 0 }
    }
}

// Snapshot of a team's score at a specific point in time
public struct IntervalTeamSnapshot: Codable {
    public var teamName: String
    public var teamColor: String
    public var totalScore: Int

    public init(teamName: String, teamColor: String, totalScore: Int) {
        self.teamName = teamName
        self.teamColor = teamColor
        self.totalScore = totalScore
    }
}

@Model
public class Interval {
    public var name: String = "" // e.g., "Q1", "Q2", "Half 1", etc.
    public var teamSnapshots: [IntervalTeamSnapshot] = []
    public var date: Date = Date.now
    public var game: Game?

    public init(name: String = "", teamSnapshots: [IntervalTeamSnapshot] = [], date: Date = .now) {
        self.name = name
        self.teamSnapshots = teamSnapshots
        self.date = date
    }

    // Helper to create interval from current teams
    public static func create(name: String, from teams: [Team]) -> Interval {
        let snapshots = teams.map { team in
            IntervalTeamSnapshot(
                teamName: team.name,
                teamColor: team.color,
                totalScore: team.score.totalScore
            )
        }
        return Interval(name: name, teamSnapshots: snapshots)
    }
}

extension Interval {
    public static func generateData(modelContext: ModelContext) {
        let snapshot1 = IntervalTeamSnapshot(teamName: "Team A", teamColor: "FF0000", totalScore: 10)
        let snapshot2 = IntervalTeamSnapshot(teamName: "Team B", teamColor: "0000FF", totalScore: 8)

        let interval1 = Interval(name: "Q1", teamSnapshots: [snapshot1, snapshot2])
        let interval2 = Interval(name: "Q2", teamSnapshots: [snapshot1, snapshot2])

        modelContext.insert(interval1)
        modelContext.insert(interval2)
    }

    // Calculate score gained in this interval compared to previous
    public func scoreGained(previousInterval: Interval?) -> [String: Int] {
        var gains: [String: Int] = [:]

        for snapshot in teamSnapshots {
            if let previousInterval = previousInterval,
               let previousSnapshot = previousInterval.teamSnapshots.first(where: { $0.teamName == snapshot.teamName }) {
                gains[snapshot.teamName] = snapshot.totalScore - previousSnapshot.totalScore
            } else {
                // First interval - the gain is the total score
                gains[snapshot.teamName] = snapshot.totalScore
            }
        }

        return gains
    }

    /// Convert SwiftData Interval to Codable format
    public func toCodable() -> CodableIntervalData {
        CodableIntervalData(
            name: name,
            teamSnapshots: teamSnapshots,
            date: date
        )
    }

    /// Create Interval from Codable format
    public static func from(codable: CodableIntervalData) -> Interval {
        Interval(
            name: codable.name,
            teamSnapshots: codable.teamSnapshots,
            date: codable.date
        )
    }
}

@Model
public class Team {
    public var score: [Score] = []
    public var name: String = ""
    public var color: String = ""
    public var creationDate: Date = Date.now
    public var game: Game?

    @Transient
    public var resolvedColor: Color {
        get {
            Color(hex: color)
        }
        set {
            self.color = newValue.toHex(alpha: false)
        }
    }

    public init(score: [Score] = [], name: String = "", color: String = "") {
        self.creationDate = .now
        self.score = score
        self.name = name
        self.color = color.isEmpty ? Color.random.toHex() : color
    }

    public static func createBaseData(modelContext: ModelContext) {
        let ta = Team(name: "Team A")
        let tb = Team(name: "Team B")

        modelContext.insert(ta)
        modelContext.insert(tb)
    }
}

extension Team {
    public func toCodable() -> CodableTeamData {
        .init(name: name, color: resolvedColor, score: score)
    }
}

extension Team {
    public static func generateData(modelContext: ModelContext) {
        let team1 = Team(score: [], name: "SDTeam_1", color: "cacaca")
        let team2 = Team(score: [.init(time: .now)], name: "SDTeam_2", color: "fafafa")

        modelContext.insert(team1)
        modelContext.insert(team2)
    }
}
