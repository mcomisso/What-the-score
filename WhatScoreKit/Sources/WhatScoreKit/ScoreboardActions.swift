import Foundation
import SwiftData

public struct TeamScore: Equatable {
    public let id: UUID
    public let name: String
    public let score: Int
}

public struct ScoreChange: Equatable {
    public let score: Int
    public let didChange: Bool
}

public enum ScoreboardActionError: LocalizedError {
    case teamNotFound
    case intervalsDisabled
    case storageFailure(String)

    public var errorDescription: String? {
        switch self {
        case .teamNotFound:
            "That team is no longer available. Choose a team again."
        case .intervalsDisabled:
            "Enable intervals in Settings before creating one."
        case .storageFailure(let detail):
            "The scoreboard could not be saved. \(detail)"
        }
    }
}

@MainActor
public enum ScoreboardActions {
    @discardableResult
    public static func addPoint(teamID: UUID, in context: ModelContext, at date: Date = .now) throws -> Int {
        let team = try requireTeam(id: teamID, in: context)
        team.score.addPoint(at: date)
        try save(context)
        return team.score.totalScore
    }

    @discardableResult
    public static func subtractPoint(
        teamID: UUID,
        allowNegativePoints: Bool,
        in context: ModelContext,
        at date: Date = .now
    ) throws -> ScoreChange {
        let team = try requireTeam(id: teamID, in: context)

        guard team.score.subtractPoint(allowNegativePoints: allowNegativePoints, at: date) else {
            return ScoreChange(score: 0, didChange: false)
        }

        try save(context)
        return ScoreChange(score: team.score.totalScore, didChange: true)
    }

    public static func currentScores(in context: ModelContext, allowNegativePoints: Bool = false) throws -> [TeamScore] {
        try storage {
            try TeamIdentity.backfill(in: context)
            let teams = try context.fetch(FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)]))
            return teams.compactMap { team in
                guard let id = team.shortcutID else { return nil }
                return TeamScore(
                    id: id,
                    name: team.name,
                    score: allowNegativePoints ? team.score.totalScore : team.score.safeTotalScore
                )
            }
        }
    }

    @discardableResult
    public static func createInterval(name: String?, enabled: Bool, in context: ModelContext) throws -> Interval {
        guard enabled else {
            throw ScoreboardActionError.intervalsDisabled
        }

        return try storage {
            let teams = try context.fetch(FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)]))
            let existing = try context.fetch(FetchDescriptor<Interval>())
            let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let selectedSport = UserDefaults.standard.string(forKey: SportStorageKeys.currentSelection)
                .flatMap(SportSelection.init(storageValue:))
            let suggestedName = selectedSport?.intervalName(number: existing.count + 1) ?? "Interval \(existing.count + 1)"
            let resolvedName = trimmedName.isEmpty ? suggestedName : trimmedName
            let interval = Interval.create(name: resolvedName, from: teams)
            context.insert(interval)
            try context.save()
            return interval
        }
    }

    private static func requireTeam(id: UUID, in context: ModelContext) throws -> Team {
        guard let team = try storage({ try TeamIdentity.team(id: id, in: context) }) else {
            throw ScoreboardActionError.teamNotFound
        }
        return team
    }

    private static func save(_ context: ModelContext) throws {
        try storage { try context.save() }
    }

    private static func storage<Value>(_ work: () throws -> Value) throws -> Value {
        do {
            return try work()
        } catch let error as ScoreboardActionError {
            throw error
        } catch {
            throw ScoreboardActionError.storageFailure(error.localizedDescription)
        }
    }
}
