import AppIntents
import Foundation
import Observation
import SwiftData
import WhatScoreIntents
import WhatScoreKit
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
@Observable
final class ScoreboardIntentRouter {
    static let shared = ScoreboardIntentRouter()

    private(set) var pendingOpenScoreboard = false

    private init() {}

    func requestOpenScoreboard() {
        pendingOpenScoreboard = true
    }

    func consumeOpenScoreboardRequest() {
        pendingOpenScoreboard = false
    }
}

struct SubtractPointIntent: AppIntent {
    static let title: LocalizedStringResource = "Subtract Point"
    static let description = IntentDescription("Remove the latest point from a team, or subtract one when negative points are enabled.")

    @Parameter(title: "Team")
    var team: TeamEntity

    init() {}

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let change = try await MainActor.run {
            let context = try ScoreboardIntentContext.make()
            let change = try ScoreboardActions.subtractPoint(
                teamID: team.id,
                allowNegativePoints: UserDefaults.standard.bool(forKey: "shouldAllowNegativePoints"),
                in: context
            )
            let currentName = try TeamIdentity.team(id: team.id, in: context)?.name ?? team.name
            return (score: change.score, didChange: change.didChange, name: currentName)
        }
        if change.didChange {
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
            return .result(value: change.score, dialog: "\(change.name) now has \(change.score) points.")
        }
        return .result(value: change.score, dialog: "\(change.name) is already at zero. No point was removed.")
    }
}

struct CreateIntervalIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Interval"
    static let description = IntentDescription("Save the current scores as a new interval.")

    @Parameter(title: "Name")
    var name: String?

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let intervalName = try await MainActor.run {
            let context = try ScoreboardIntentContext.make()
            let interval = try ScoreboardActions.createInterval(
                name: name,
                enabled: UserDefaults.standard.bool(forKey: "hasEnabledIntervals"),
                in: context
            )
            return interval.name
        }
        return .result(dialog: "Saved \(intervalName) with the current scores.")
    }
}

struct OpenScoreboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Scoreboard"
    static let description = IntentDescription("Open the live scoreboard in What the Score.")
    static let openAppWhenRun = true

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            ScoreboardIntentRouter.shared.requestOpenScoreboard()
        }
        return .result()
    }
}

struct ScoreMatchingIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [WhatScoreIntentsPackage.self]
    }
}

struct ScoreboardShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddPointIntent(),
            phrases: ["Add a point in \(.applicationName)"],
            shortTitle: "Add Point",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: SubtractPointIntent(),
            phrases: ["Subtract a point in \(.applicationName)"],
            shortTitle: "Subtract Point",
            systemImageName: "minus.circle"
        )
        AppShortcut(
            intent: GetCurrentScoresIntent(),
            phrases: ["Get scores in \(.applicationName)"],
            shortTitle: "Get Scores",
            systemImageName: "number"
        )
        AppShortcut(
            intent: CreateIntervalIntent(),
            phrases: ["Create an interval in \(.applicationName)"],
            shortTitle: "Create Interval",
            systemImageName: "flag"
        )
        AppShortcut(
            intent: OpenScoreboardIntent(),
            phrases: ["Open scoreboard in \(.applicationName)"],
            shortTitle: "Open Scoreboard",
            systemImageName: "rectangle.on.rectangle"
        )
    }
}
