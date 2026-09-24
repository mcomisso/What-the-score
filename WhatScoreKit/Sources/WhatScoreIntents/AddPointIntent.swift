import AppIntents
import SwiftData
import WhatScoreKit
#if canImport(WidgetKit)
import WidgetKit
#endif

public struct AddPointIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Point"
    public static let description = IntentDescription("Add one point to a team.")

    @Parameter(title: "Team")
    public var team: TeamEntity

    public init() {}

    public init(team: TeamEntity) {
        self.team = team
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let result = try await MainActor.run {
            let context = try ScoreboardIntentContext.make()
            let score = try ScoreboardActions.addPoint(teamID: team.id, in: context)
            let currentName = try TeamIdentity.team(id: team.id, in: context)?.name ?? team.name
            return (score: score, name: currentName)
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        return .result(value: result.score, dialog: "\(result.name) now has \(result.score) points.")
    }
}
