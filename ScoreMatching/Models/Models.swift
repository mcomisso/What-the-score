import Foundation
import SwiftUI
import Observation

struct Score: Codable {
    var time: Date
}

struct Interval {
    var id: Int
    var points: [TeamsData]
}

@Observable
class TeamsData: Identifiable, Codable {
    let id: UUID = UUID()
    var score: [Score] = []

    var name: String
    var color: Color = .random

    init(_ name: String, score: [Score] = [], color: Color = .random) {
        self.name = name
        self.score = score
        self.color = color
    }

    func toCodable() -> CodableTeamData {
        .init(name: name, color: color, score: score)
    }
}

extension TeamsData: Equatable {
    static func == (lhs: TeamsData, rhs: TeamsData) -> Bool {
        lhs.id == rhs.id &&
        lhs.count == rhs.count &&
        lhs.name == rhs.name
    }
}

extension TeamsData {
    var count: Int {
        score.count
    }
}
