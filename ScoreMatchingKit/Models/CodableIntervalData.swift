import Foundation
import SwiftUI

/// Codable representation of Interval data for Watch Connectivity
public struct CodableIntervalData: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let teamSnapshots: [IntervalTeamSnapshot]
    public let date: Date

    public init(id: UUID = UUID(), name: String, teamSnapshots: [IntervalTeamSnapshot], date: Date) {
        self.id = id
        self.name = name
        self.teamSnapshots = teamSnapshots
        self.date = date
    }
}

public extension Interval {
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
