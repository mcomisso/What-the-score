import Foundation
import SwiftUI

struct Interval {
    var id: Int
    var points: [TeamsData]
}

struct CodableTeamData: Codable {
    let name: String
    let color: Color
    let count: Int
}

extension CodableTeamData: Identifiable {
    var id: String { name }
}

class TeamsData: ObservableObject, Identifiable, Equatable {
    static func == (lhs: TeamsData, rhs: TeamsData) -> Bool {
        lhs.id == rhs.id &&
        lhs.count == rhs.count &&
        lhs.name == rhs.name
    }

    let id: UUID = UUID()
    var count: Int = 0
    @Published var name: String
    @Published var color: Color = .random

    init(_ name: String) {
        self.name = name
    }

    func toCodable() -> CodableTeamData {
        .init(name: name, color: color, count: count)
    }
}
