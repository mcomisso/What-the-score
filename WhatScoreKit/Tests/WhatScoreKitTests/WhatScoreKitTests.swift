import Testing
@testable import WhatScoreKit
import Foundation
import SwiftData

private func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([Team.self, Interval.self, Game.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}

@Test func updateModels_updatesTeamScores_whenOnlyScoreValuesChange() throws {
    let modelContainer = try makeTestContainer()
    let context = ModelContext(modelContainer)
    let service = SwiftDataConversionService()

    let baseTime = Date(timeIntervalSince1970: 1_700_000_000)
    let team = Team(score: [.init(time: baseTime, value: 1)], name: "Team A", color: "FF0000")
    context.insert(team)
    try context.save()

    let syncData = SyncData(
        teams: [
            .init(
                name: "Team A",
                color: "FF0000",
                scores: [.init(time: baseTime, value: 2)]
            )
        ],
        intervals: []
    )

    try service.updateModels(with: syncData, in: context)

    let teams = try context.fetch(FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)]))
    #expect(teams.count == 1)
    #expect(teams[0].score.count == 1)
    #expect(teams[0].score[0].value == 2)
}

@Test func updateModels_updatesIntervalSnapshots_whenNameAndCountDoNotChange() throws {
    let modelContainer = try makeTestContainer()
    let context = ModelContext(modelContainer)
    let service = SwiftDataConversionService()

    let team = Team(score: [.init(time: .now, value: 1)], name: "Team A", color: "FF0000")
    context.insert(team)

    let intervalDate = Date(timeIntervalSince1970: 1_700_000_100)
    let existingInterval = Interval(
        name: "Q1",
        teamSnapshots: [.init(teamName: "Team A", teamColor: "FF0000", totalScore: 1)],
        date: intervalDate
    )
    context.insert(existingInterval)
    try context.save()

    let syncData = SyncData(
        teams: [
            .init(
                name: "Team A",
                color: "FF0000",
                scores: [.init(time: team.score[0].time, value: 1)]
            )
        ],
        intervals: [
            .init(
                name: "Q1",
                date: intervalDate,
                teamSnapshots: [.init(teamName: "Team A", teamColor: "FF0000", totalScore: 5)]
            )
        ]
    )

    try service.updateModels(with: syncData, in: context)

    let intervals = try context.fetch(FetchDescriptor<Interval>(sortBy: [SortDescriptor(\.date)]))
    #expect(intervals.count == 1)
    #expect(intervals[0].teamSnapshots.count == 1)
    #expect(intervals[0].teamSnapshots[0].totalScore == 5)
}
