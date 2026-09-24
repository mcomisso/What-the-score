import SwiftData
import WhatScoreKit

public enum ScoreboardIntentContext {
    @MainActor
    public static func make() throws -> ModelContext {
        do {
            return ModelContext(try ScoreboardStore.makeContainer())
        } catch {
            throw ScoreboardActionError.storageFailure(error.localizedDescription)
        }
    }
}
