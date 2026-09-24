import Foundation
import SwiftData
import XCTest
@testable import WhatScoreKit

@MainActor
final class ScoreboardActionsTests: XCTestCase {
private func makeScoreboardContext() throws -> ModelContext {
    let schema = Schema([Team.self, Interval.self, Game.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContext(ModelContainer(for: schema, configurations: [configuration]))
}

func testTeamIDsBackfillOnceAndRemainIndependentOfNames() throws {
    let context = try makeScoreboardContext()
    let first = Team(name: "Same", color: "FF0000")
    let second = Team(name: "Same", color: "0000FF")
    first.shortcutID = nil // Simulate a record from the old schema.
    second.shortcutID = nil
    context.insert(first)
    context.insert(second)
    try context.save()

    XCTAssertEqual(try TeamIdentity.backfill(in: context), 2)
    let firstID = try XCTUnwrap(first.shortcutID)
    let secondID = try XCTUnwrap(second.shortcutID)
    XCTAssertNotEqual(firstID, secondID)
    XCTAssertEqual(try TeamIdentity.backfill(in: context), 0)

    first.name = "Renamed"
    try context.save()
    XCTAssertEqual(try TeamIdentity.team(id: firstID, in: context)?.name, "Renamed")
    XCTAssertEqual(try TeamIdentity.team(id: secondID, in: context)?.name, "Same")
}

func testTeamIDsRepairDuplicatesAndRejectStaleSelection() throws {
    let context = try makeScoreboardContext()
    let sharedID = UUID()
    let first = Team(name: "First", shortcutID: sharedID)
    let second = Team(name: "Second", shortcutID: sharedID)
    context.insert(first)
    context.insert(second)
    try context.save()

    XCTAssertEqual(try TeamIdentity.backfill(in: context), 1)
    XCTAssertNotEqual(first.shortcutID, second.shortcutID)

    let staleID = UUID()
    XCTAssertNil(try TeamIdentity.team(id: staleID, in: context))
    XCTAssertThrowsError(
        try ScoreboardActions.addPoint(teamID: staleID, in: context)
    )
}

func testScoreActionsFollowSwipeRules() throws {
    let context = try makeScoreboardContext()
    let team = Team(name: "Home")
    context.insert(team)
    try context.save()
    let id = try XCTUnwrap(team.shortcutID)

    XCTAssertEqual(try ScoreboardActions.subtractPoint(teamID: id, allowNegativePoints: false, in: context), ScoreChange(score: 0, didChange: false))
    XCTAssertEqual(try ScoreboardActions.addPoint(teamID: id, in: context), 1)
    XCTAssertEqual(try ScoreboardActions.addPoint(teamID: id, in: context), 2)
    XCTAssertEqual(try ScoreboardActions.subtractPoint(teamID: id, allowNegativePoints: false, in: context), ScoreChange(score: 1, didChange: true))
    XCTAssertEqual(team.score.count, 1)
    XCTAssertEqual(try ScoreboardActions.subtractPoint(teamID: id, allowNegativePoints: true, in: context), ScoreChange(score: 0, didChange: true))
    XCTAssertEqual(team.score.last?.value, -1)
    XCTAssertEqual(try ScoreboardActions.subtractPoint(teamID: id, allowNegativePoints: true, in: context), ScoreChange(score: -1, didChange: true))
}

func testCurrentScoresKeepDuplicateNamesSeparateAndRespectDisplayRule() throws {
    let context = try makeScoreboardContext()
    let first = Team(score: [Score(time: .now, value: -2)], name: "Same")
    let second = Team(score: [Score(time: .now, value: 3)], name: "Same")
    context.insert(first)
    context.insert(second)
    try context.save()

    let displayScores = try ScoreboardActions.currentScores(in: context)
    XCTAssertEqual(displayScores.count, 2)
    XCTAssertEqual(Set(displayScores.map(\.id)).count, 2)
    XCTAssertEqual(displayScores.first(where: { $0.id == first.shortcutID })?.score, 0)
    XCTAssertEqual(displayScores.first(where: { $0.id == second.shortcutID })?.score, 3)
    XCTAssertEqual(try ScoreboardActions.currentScores(in: context, allowNegativePoints: true)
        .first(where: { $0.id == first.shortcutID })?.score, -2)
}

func testIntervalsUseCurrentScoresAndRespectSetting() throws {
    let context = try makeScoreboardContext()
    let team = Team(score: [Score(time: .now, value: 4)], name: "Home", color: "FF0000")
    context.insert(team)
    try context.save()

    XCTAssertThrowsError(
        try ScoreboardActions.createInterval(name: nil, enabled: false, in: context)
    )
    XCTAssertTrue(try context.fetch(FetchDescriptor<Interval>()).isEmpty)

    let first = try ScoreboardActions.createInterval(name: nil, enabled: true, in: context)
    XCTAssertEqual(first.name, "Interval 1")
    XCTAssertEqual(first.teamSnapshots.first?.totalScore, 4)
    let second = try ScoreboardActions.createInterval(name: "  Q2  ", enabled: true, in: context)
    XCTAssertEqual(second.name, "Q2")
    let third = try ScoreboardActions.createInterval(name: "  ", enabled: true, in: context)
    XCTAssertEqual(third.name, "Interval 3")
}
}
