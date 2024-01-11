import Foundation
import SwiftData
import SwiftUI

struct Score: Codable {
    var time: Date
}

@Model
public class Interval {
    var teams: [Team]
    var duration: Double

    init(teams: [Team], duration: Double) {
        self.teams = teams
        self.duration = duration
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
