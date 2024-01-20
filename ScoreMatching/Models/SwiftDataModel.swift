import Foundation
import SwiftData
import SwiftUI

@Model
public class Game {
    var date: Date
    var teams: [Team]
    var intervals: [Interval]

    init(date: Date = .now, teams: [Team], intervals: [Interval]) {
        self.date = date
        self.teams = teams
        self.intervals = intervals
    }
}

struct Score: Codable {
    var time: Date
    var value: Int

    init(time: Date, value: Int = 1) {
        self.time = time
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.time = try container.decode(Date.self, forKey: .time)
        self.value = try container.decodeIfPresent(Int.self, forKey: .value) ?? 1
    }
}

extension Array where Element == Score {
    var totalScore: Int {
        map(\.value).reduce(0, +)
    }
}

@Model
public class Interval {
    var teams: [Team]
    var duration: Double
    var date: Date

    init(teams: [Team], duration: Double, date: Date = .now) {
        self.teams = teams
        self.duration = duration
        self.date = date
    }
}

extension Interval {
    static func generateData(modelContext: ModelContext) {
        let interval1 = Interval(teams: [], duration: 10)
        let interval2 = Interval(teams: [], duration: 10)

        modelContext.insert(interval1)
        modelContext.insert(interval2)
    }
}

@Model
public class Team {
    var score: [Score] = []
    var name: String = ""
    var color: String

    var creationDate: Date

    @Transient
    var resolvedColor: Color {
        get {
            Color(hex: color)
        }
        set {
            self.color = newValue.toHex(alpha: false)
        }
    }

    init(score: [Score] = [], name: String, color: String = Color.random.toHex()) {
        self.creationDate = .now
        self.score = score
        self.name = name
        self.color = color
        self.resolvedColor = Color(hex: color)
    }

    static func createBaseData(modelContext: ModelContext) {
        let ta = Team(name: "Team A")
        let tb = Team(name: "Team B")

        modelContext.insert(ta)
        modelContext.insert(tb)
    }
}

extension Team {
    func toCodable() -> CodableTeamData {
        .init(name: name, color: resolvedColor, score: score)
    }
}

extension Team {
    static func generateData(modelContext: ModelContext) {
        let team1 = Team(score: [], name: "SDTeam_1", color: "cacaca")
        let team2 = Team(score: [.init(time: .now)], name: "SDTeam_2", color: "fafafa")

        modelContext.insert(team1)
        modelContext.insert(team2)
    }
}
