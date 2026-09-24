import Foundation
import SwiftData

public enum ScoreboardStore {
    public static func makeContainer() throws -> ModelContainer {
        let schema = Schema([Team.self, Interval.self, Game.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.mcsoftware.whatTheScore"),
            cloudKitDatabase: .private("iCloud.com.mcomisso.ScoreMatching")
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@MainActor
public enum TeamIdentity {
    /// Assigns stable IDs to records created before shortcuts existed. Also repairs duplicate IDs.
    @discardableResult
    public static func backfill(in context: ModelContext) throws -> Int {
        let teams = try context.fetch(FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)]))
        var seen = Set<UUID>()
        var changed = 0

        for team in teams {
            if let id = team.shortcutID, seen.insert(id).inserted {
                continue
            }

            var id = UUID()
            while seen.contains(id) {
                id = UUID()
            }
            team.shortcutID = id
            seen.insert(id)
            changed += 1
        }

        if changed > 0 {
            try context.save()
        }
        return changed
    }

    public static func team(id: UUID, in context: ModelContext) throws -> Team? {
        let teams = try context.fetch(FetchDescriptor<Team>())
        return teams.first { $0.shortcutID == id }
    }
}
