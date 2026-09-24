import AppIntents
import Foundation
import SwiftData
import WhatScoreKit

/// A small, stable representation of a team for Shortcuts and widgets.
public struct TeamEntity: AppEntity, Sendable {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Team"
    public static let defaultQuery = TeamQuery()

    public let id: UUID
    public let name: String
    public let detail: String?

    public var displayRepresentation: DisplayRepresentation {
        if let detail {
            DisplayRepresentation(title: "\(name)", subtitle: "\(detail)")
        } else {
            DisplayRepresentation(title: "\(name)")
        }
    }

    public init(id: UUID, name: String, detail: String? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
    }
}

public struct TeamQuery: EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [UUID]) async throws -> [TeamEntity] {
        let requested = Set(identifiers)
        return try await allEntities().filter { requested.contains($0.id) }
    }

    public func suggestedEntities() async throws -> [TeamEntity] {
        try await allEntities()
    }

    public func entities(matching string: String) async throws -> [TeamEntity] {
        try await allEntities().filter { $0.name.localizedStandardContains(string) }
    }

    private func allEntities() async throws -> [TeamEntity] {
        try await MainActor.run {
            let context = try ScoreboardIntentContext.make()
            try TeamIdentity.backfill(in: context)
            let teams = try context.fetch(FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)]))
            let nameCounts = Dictionary(teams.map { ($0.name.localizedLowercase, 1) }, uniquingKeysWith: +)
            return teams.enumerated().compactMap { index, team -> TeamEntity? in
                guard let id = team.shortcutID else { return nil }
                let detail = nameCounts[team.name.localizedLowercase, default: 0] > 1
                    ? "Scoreboard position \(index + 1)"
                    : nil
                return TeamEntity(id: id, name: team.name, detail: detail)
            }
        }
    }
}
