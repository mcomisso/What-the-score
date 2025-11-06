import Foundation
import SwiftUI

public struct CodableTeamData: Codable {
    public let name: String
    public let color: Color
    public let score: [Score]

    public init(name: String, color: Color, score: [Score]) {
        self.name = name
        self.color = color
        self.score = score
    }
}

extension CodableTeamData: Identifiable {
    public var id: String { name }
}

public extension CodableTeamData {
    func toTeam() -> Team {
        Team(score: score, name: name, color: color.toHex())
    }
}
