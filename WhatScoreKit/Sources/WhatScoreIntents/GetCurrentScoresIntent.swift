import AppIntents
import Foundation
import SwiftData
import WhatScoreKit

public struct GetCurrentScoresIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Current Scores"
    public static let description = IntentDescription("Get the current score for every team.")

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let summary = try await MainActor.run {
            let context = try ScoreboardIntentContext.make()
            let scores = try ScoreboardActions.currentScores(
                in: context,
                allowNegativePoints: UserDefaults.standard.bool(forKey: "shouldAllowNegativePoints")
            )
            return scores.isEmpty
                ? "There are no teams yet. Open What the Score to set up a game."
                : scores.map { "\($0.name): \($0.score)" }.joined(separator: ", ")
        }
        return .result(value: summary, dialog: "\(summary)")
    }
}
