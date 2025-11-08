import Foundation

/// Structured data model for syncing between iOS and watchOS
public struct SyncData: Codable {
    public let teams: [TeamData]
    public let intervals: [IntervalData]
    public let settings: SettingsData?

    public init(teams: [TeamData], intervals: [IntervalData], settings: SettingsData? = nil) {
        self.teams = teams
        self.intervals = intervals
        self.settings = settings
    }

    /// Convert to dictionary for WatchConnectivity
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "teams": teams.map { $0.toDictionary() },
            "intervals": intervals.map { $0.toDictionary() }
        ]

        if let settings = settings {
            dict["settings"] = settings.toDictionary()
        }

        return dict
    }

    /// Create from dictionary received via WatchConnectivity
    public static func from(dictionary: [String: Any]) -> SyncData? {
        guard let teamsData = dictionary["teams"] as? [[String: Any]] else {
            return nil
        }

        let teams = teamsData.compactMap { TeamData.from(dictionary: $0) }

        let intervalsData = (dictionary["intervals"] as? [[String: Any]]) ?? []
        let intervals = intervalsData.compactMap { IntervalData.from(dictionary: $0) }

        var settings: SettingsData? = nil
        if let settingsDict = dictionary["settings"] as? [String: Any] {
            settings = SettingsData.from(dictionary: settingsDict)
        }

        return SyncData(teams: teams, intervals: intervals, settings: settings)
    }
}

/// Team data for syncing
public struct TeamData: Codable {
    public let name: String
    public let color: String
    public let scores: [ScoreData]

    public init(name: String, color: String, scores: [ScoreData]) {
        self.name = name
        self.color = color
        self.scores = scores
    }

    public func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "color": color,
            "score": scores.map { $0.toDictionary() }
        ]
    }

    public static func from(dictionary: [String: Any]) -> TeamData? {
        guard let name = dictionary["name"] as? String,
              let color = dictionary["color"] as? String else {
            return nil
        }

        let scoreData = (dictionary["score"] as? [[String: Any]]) ?? []
        let scores = scoreData.compactMap { ScoreData.from(dictionary: $0) }

        return TeamData(name: name, color: color, scores: scores)
    }
}

/// Score data for syncing
public struct ScoreData: Codable {
    public let time: Date
    public let value: Int

    public init(time: Date, value: Int) {
        self.time = time
        self.value = value
    }

    public func toDictionary() -> [String: Any] {
        return [
            "time": time.timeIntervalSince1970,
            "value": value
        ]
    }

    public static func from(dictionary: [String: Any]) -> ScoreData? {
        guard let timeInterval = dictionary["time"] as? TimeInterval,
              let value = dictionary["value"] as? Int else {
            return nil
        }

        return ScoreData(time: Date(timeIntervalSince1970: timeInterval), value: value)
    }
}

/// Interval data for syncing
public struct IntervalData: Codable {
    public let name: String
    public let date: Date
    public let teamSnapshots: [IntervalTeamSnapshot]

    public init(name: String, date: Date, teamSnapshots: [IntervalTeamSnapshot]) {
        self.name = name
        self.date = date
        self.teamSnapshots = teamSnapshots
    }

    public func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "date": date.timeIntervalSince1970,
            "teamSnapshots": teamSnapshots.map { snapshot in
                [
                    "teamName": snapshot.teamName,
                    "teamColor": snapshot.teamColor,
                    "totalScore": snapshot.totalScore
                ]
            }
        ]
    }

    public static func from(dictionary: [String: Any]) -> IntervalData? {
        guard let name = dictionary["name"] as? String,
              let dateTimestamp = dictionary["date"] as? TimeInterval else {
            return nil
        }

        let snapshotsData = (dictionary["teamSnapshots"] as? [[String: Any]]) ?? []
        let snapshots = snapshotsData.compactMap { dict -> IntervalTeamSnapshot? in
            guard let teamName = dict["teamName"] as? String,
                  let teamColor = dict["teamColor"] as? String,
                  let totalScore = dict["totalScore"] as? Int else {
                return nil
            }
            return IntervalTeamSnapshot(teamName: teamName, teamColor: teamColor, totalScore: totalScore)
        }

        return IntervalData(
            name: name,
            date: Date(timeIntervalSince1970: dateTimestamp),
            teamSnapshots: snapshots
        )
    }
}

/// Settings data for syncing
public struct SettingsData: Codable {
    public let allowNegativePoints: Bool
    public let intervalsEnabled: Bool

    public init(allowNegativePoints: Bool, intervalsEnabled: Bool) {
        self.allowNegativePoints = allowNegativePoints
        self.intervalsEnabled = intervalsEnabled
    }

    public func toDictionary() -> [String: Any] {
        return [
            "allowNegativePoints": allowNegativePoints,
            "intervalsEnabled": intervalsEnabled
        ]
    }

    public static func from(dictionary: [String: Any]) -> SettingsData? {
        guard let allowNegativePoints = dictionary["allowNegativePoints"] as? Bool,
              let intervalsEnabled = dictionary["intervalsEnabled"] as? Bool else {
            return nil
        }

        return SettingsData(
            allowNegativePoints: allowNegativePoints,
            intervalsEnabled: intervalsEnabled
        )
    }
}
