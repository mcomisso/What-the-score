import Foundation
import SwiftUI

/// Codable representation of Interval data for Watch Connectivity
struct CodableIntervalData: Codable, Identifiable {
    let id: UUID
    let name: String
    let teamSnapshots: [IntervalTeamSnapshot]
    let date: Date

    init(id: UUID = UUID(), name: String, teamSnapshots: [IntervalTeamSnapshot], date: Date) {
        self.id = id
        self.name = name
        self.teamSnapshots = teamSnapshots
        self.date = date
    }
}

extension Interval {
    /// Convert SwiftData Interval to Codable format
    func toCodable() -> CodableIntervalData {
        CodableIntervalData(
            name: name,
            teamSnapshots: teamSnapshots,
            date: date
        )
    }

    /// Create Interval from Codable format
    static func from(codable: CodableIntervalData) -> Interval {
        Interval(
            name: codable.name,
            teamSnapshots: codable.teamSnapshots,
            date: codable.date
        )
    }
}
