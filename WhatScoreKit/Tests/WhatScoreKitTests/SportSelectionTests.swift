import Testing
@testable import WhatScoreKit
import Foundation

@Test func sportPresetsUseExpectedIntervalTerms() {
    #expect(SportPreset.tennis.suggestedIntervalName(number: 2) == "Set 2")
    #expect(SportPreset.basketball.suggestedIntervalName(number: 2) == "Quarter 2")
    #expect(SportPreset.football.suggestedIntervalName(number: 2) == "Half 2")
    #expect(SportPreset.rugby.intervalPlural == "Halves")
    #expect(SportPreset.netball.intervalPlural == "Quarters")
    #expect(SportPreset.americanFootball.intervalSingular == "Quarter")
    #expect(SportPreset.hockey.intervalSingular == "Period")
    #expect(SportPreset.cricket.intervalPlural == "Innings")
    #expect(SportPreset.cardGames.intervalSingular == "Round")
}

@Test func customSportUsesUserSuppliedNameAndIntervalTerms() {
    let sport = SportSelection(
        preset: .custom,
        customName: "  Canasta  ",
        customIntervalSingular: "  Hand  ",
        customIntervalPlural: "  Hands  "
    )

    #expect(sport.displayName == "Canasta")
    #expect(sport.intervalSingular == "Hand")
    #expect(sport.intervalPlural == "Hands")
    #expect(sport.intervalName(number: 3) == "Hand 3")
}

@Test func presetCanUseCustomIntervalTerm() {
    let sport = SportSelection(preset: .tennis, customIntervalSingular: "Match", customIntervalPlural: "Matches")

    #expect(sport.displayName == "Tennis")
    #expect(sport.intervalName(number: 2) == "Match 2")
    #expect(sport.intervalPlural == "Matches")
}

@Test func sportSelectionRoundTripsThroughStorageString() {
    let original = SportSelection(
        preset: .custom,
        customName: "Bridge",
        customIntervalSingular: "Deal",
        customIntervalPlural: "Deals"
    )

    #expect(SportSelection(storageValue: original.storageValue) == original)
    #expect(SportSelection(storageValue: "") == nil)
    #expect(SportSelection(storageValue: "invalid") == nil)
}

@Test func sportPresetsProvideScoringValues() {
    #expect(SportPreset.basketball.scoreValues == [1, 2, 3])
    #expect(SportPreset.rugby.scoreValues == [5, 3, 2, 7])
    #expect(SportPreset.americanFootball.scoreValues == [6, 3, 2, 1])
    #expect(SportPreset.cricket.scoreValues == [1, 2, 3, 4, 6])
    #expect(SportPreset.tennis.scoreValues == [1])
    #expect(SportPreset.cardGames.scoreValues == [1])
}

@Test func customScoringValuesOverridePresetWhenValid() {
    let custom = SportSelection(preset: .cardGames, customScoreValues: [5, 10, 25])
    #expect(custom.scoreValues == [5, 10, 25])
    #expect(SportSelection(storageValue: custom.storageValue)?.scoreValues == [5, 10, 25])

    #expect(SportSelection(preset: .basketball, customScoreValues: []).scoreValues == [1, 2, 3])
    #expect(SportSelection(preset: .basketball, customScoreValues: [0, 2]).scoreValues == [1, 2, 3])
    #expect(SportSelection(preset: .basketball, customScoreValues: [2, 2]).scoreValues == [1, 2, 3])
}

@Test func olderStoredSelectionWithoutCustomScoresStillLoads() {
    let oldValue = """
        {"preset":"rugby","customName":"","customIntervalSingular":"","customIntervalPlural":""}
        """
    #expect(SportSelection(storageValue: oldValue)?.scoreValues == [5, 3, 2, 7])
    #expect(SportSelection(storageValue: oldValue)?.sportID == "rugby")
    #expect(SportSelection(storageValue: oldValue)?.definition.symbolName == "figure.rugby")
}

@Test func olderStoredDefinitionsWithoutSymbolsStillLoad() {
    let oldValue = """
        {"definition":{"id":"tennis","name":"Tennis","intervalSingular":"Set","intervalPlural":"Sets","scoreValues":[1]},"customName":"","customIntervalSingular":"","customIntervalPlural":"","customScoreValues":[]}
        """

    #expect(SportSelection(storageValue: oldValue)?.definition.symbolName == "tennisball.fill")
}

@Test func remoteCatalogWithoutSymbolsUsesKnownOrGenericIcons() throws {
    let oldCatalog = """
        {"schemaVersion":1,"sports":[
            {"id":"football","name":"Football","intervalSingular":"Half","intervalPlural":"Halves","scoreValues":[1]},
            {"id":"pickleball","name":"Pickleball","intervalSingular":"Game","intervalPlural":"Games","scoreValues":[1]}
        ]}
        """
    let sports = try SportCatalog.validated(data: Data(oldCatalog.utf8)).sports

    #expect(sports[0].symbolName == "soccerball")
    #expect(sports[1].symbolName == SportDefinition.fallbackSymbolName)
}

@Test func remoteSportSelectionKeepsDefinitionAfterCatalogChanges() {
    let original = SportDefinition(
        id: "pickleball",
        name: "Pickleball",
        intervalSingular: "Game",
        intervalPlural: "Games",
        scoreValues: [1, 2]
    )
    let selection = SportSelection(definition: original)
    let stored = SportSelection(storageValue: selection.storageValue)

    #expect(stored?.sportID == "pickleball")
    #expect(stored?.preset == nil)
    #expect(stored?.definition == original)
    #expect(stored?.intervalName(number: 2) == "Game 2")
    #expect(stored?.scoreValues == [1, 2])
}

@Test func catalogAcceptsValidRemoteSportAndRejectsBadData() throws {
    let sport = SportDefinition(
        id: "pickleball",
        name: "Pickleball",
        intervalSingular: "Game",
        intervalPlural: "Games",
        scoreValues: [1]
    )
    let valid = SportCatalog(sports: [sport])
    #expect(try SportCatalog.validated(data: JSONEncoder().encode(valid)) == valid)

    let duplicate = SportCatalog(sports: [sport, sport])
    #expect(throws: SportCatalogError.duplicateID) {
        try SportCatalog.validated(data: JSONEncoder().encode(duplicate))
    }
    #expect(throws: SportCatalogError.unsupportedVersion) {
        try SportCatalog.validated(data: JSONEncoder().encode(SportCatalog(schemaVersion: 2, sports: [sport])))
    }
    #expect(throws: SportCatalogError.invalidSport) {
        try SportCatalog.validated(data: JSONEncoder().encode(SportCatalog(sports: [
            SportDefinition(id: "bad id", name: "Bad", intervalSingular: "Round", intervalPlural: "Rounds", scoreValues: [1])
        ])))
    }
    #expect(throws: SportCatalogError.invalidSport) {
        try SportCatalog.validated(data: JSONEncoder().encode(SportCatalog(sports: [
            SportDefinition(id: "badIcon", name: "Bad icon", symbolName: "bad icon", intervalSingular: "Round", intervalPlural: "Rounds", scoreValues: [1])
        ])))
    }
    #expect(throws: SportCatalogError.tooLarge) {
        try SportCatalog.validated(data: Data(repeating: 0, count: 65_537))
    }
}

@Test func scoreAddsRequestedValueWhileOldCallDefaultsToOne() {
    var scores: [Score] = []
    scores.addPoint(value: 3, at: Date(timeIntervalSince1970: 100))
    scores.addPoint(at: Date(timeIntervalSince1970: 101))

    #expect(scores.map(\.value) == [3, 1])
    #expect(scores.totalScore == 4)
}
