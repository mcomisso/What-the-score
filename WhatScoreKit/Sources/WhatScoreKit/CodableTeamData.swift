import Foundation
import SwiftUI

struct CodableTeamData: Codable {
    let name: String
    let color: Color
    let score: [Score]
}

extension CodableTeamData: Identifiable {
    var id: String { name }
}

extension CodableTeamData {
    func toTeam() -> Team {
        Team(score: score, name: name, color: color.toHex())
    }
}
