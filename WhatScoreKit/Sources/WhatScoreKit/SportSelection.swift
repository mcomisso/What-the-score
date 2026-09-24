import Foundation

/// Catalog data copied into a game selection so later catalog edits do not change that game.
public struct SportDefinition: Codable, Equatable, Identifiable {
    public static let fallbackSymbolName = "sportscourt.fill"

    public let id: String
    public let name: String
    public let symbolName: String
    public let intervalSingular: String
    public let intervalPlural: String
    public let scoreValues: [Int]

    public init(
        id: String,
        name: String,
        symbolName: String? = nil,
        intervalSingular: String,
        intervalPlural: String,
        scoreValues: [Int]
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName ?? SportPreset(rawValue: id)?.symbolName ?? Self.fallbackSymbolName
        self.intervalSingular = intervalSingular
        self.intervalPlural = intervalPlural
        self.scoreValues = scoreValues
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbolName, intervalSingular, intervalPlural, scoreValues
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbolName = try container.decodeIfPresent(String.self, forKey: .symbolName)
            ?? SportPreset(rawValue: id)?.symbolName
            ?? Self.fallbackSymbolName
        intervalSingular = try container.decode(String.self, forKey: .intervalSingular)
        intervalPlural = try container.decode(String.self, forKey: .intervalPlural)
        scoreValues = try container.decode([Int].self, forKey: .scoreValues)
    }
}

public enum SportCatalogError: Error, Equatable {
    case tooLarge
    case unsupportedVersion
    case invalidCount
    case duplicateID
    case invalidSport
}

/// A data-only list. The app accepts only version 1 and keeps its last valid copy.
public struct SportCatalog: Codable, Equatable {
    public let schemaVersion: Int
    public let sports: [SportDefinition]

    public init(schemaVersion: Int = 1, sports: [SportDefinition]) {
        self.schemaVersion = schemaVersion
        self.sports = sports
    }

    public static var builtIn: SportCatalog {
        SportCatalog(sports: SportPreset.allCases.map(\.definition))
    }

    public static func validated(data: Data) throws -> SportCatalog {
        guard data.count <= 65_536 else { throw SportCatalogError.tooLarge }
        let catalog = try JSONDecoder().decode(SportCatalog.self, from: data)
        try catalog.validate()
        return catalog
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw SportCatalogError.unsupportedVersion }
        guard (1...100).contains(sports.count) else { throw SportCatalogError.invalidCount }
        guard Set(sports.map(\.id)).count == sports.count else { throw SportCatalogError.duplicateID }

        for sport in sports {
            let allowedIDCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
            guard !sport.id.isEmpty,
                  sport.id.count <= 40,
                  sport.id.unicodeScalars.allSatisfy(allowedIDCharacters.contains),
                  isValidLabel(sport.name, limit: 80),
                  isValidSymbolName(sport.symbolName),
                  isValidLabel(sport.intervalSingular, limit: 40),
                  isValidLabel(sport.intervalPlural, limit: 40),
                  (1...8).contains(sport.scoreValues.count),
                  sport.scoreValues.allSatisfy({ (1...1_000).contains($0) }),
                  Set(sport.scoreValues).count == sport.scoreValues.count else {
                throw SportCatalogError.invalidSport
            }
        }
    }

    private func isValidLabel(_ value: String, limit: Int) -> Bool {
        !value.isEmpty && value.count <= limit && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValidSymbolName(_ value: String) -> Bool {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.")
        return !value.isEmpty && value.count <= 80 && value.unicodeScalars.allSatisfy(allowedCharacters.contains)
    }
}

/// A stable identifier for a sport and its usual way of dividing play.
public enum SportPreset: String, CaseIterable, Identifiable, Codable {
    case tennis
    case basketball
    case football
    case rugby
    case netball
    case americanFootball
    case hockey
    case volleyball
    case cricket
    case baseball
    case badminton
    case tableTennis
    case golf
    case handball
    case boxing
    case cardGames
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tennis: "Tennis"
        case .basketball: "Basketball"
        case .football: "Football"
        case .rugby: "Rugby"
        case .netball: "Netball"
        case .americanFootball: "American football"
        case .hockey: "Hockey"
        case .volleyball: "Volleyball"
        case .cricket: "Cricket"
        case .baseball: "Baseball"
        case .badminton: "Badminton"
        case .tableTennis: "Table tennis"
        case .golf: "Golf"
        case .handball: "Handball"
        case .boxing: "Boxing"
        case .cardGames: "Card games"
        case .custom: "Custom game"
        }
    }

    public var intervalSingular: String {
        switch self {
        case .tennis, .volleyball, .badminton, .tableTennis: "Set"
        case .basketball, .netball, .americanFootball: "Quarter"
        case .football, .rugby, .handball: "Half"
        case .hockey: "Period"
        case .cricket: "Innings"
        case .baseball: "Inning"
        case .golf: "Hole"
        case .boxing, .cardGames: "Round"
        case .custom: "Round"
        }
    }

    public var intervalPlural: String {
        switch self {
        case .football, .rugby, .handball: "Halves"
        case .cricket: "Innings"
        default: "\(intervalSingular)s"
        }
    }

    public func suggestedIntervalName(number: Int) -> String {
        "\(intervalSingular) \(number)"
    }

    public var scoreValues: [Int] {
        switch self {
        case .basketball: [1, 2, 3]
        case .rugby: [5, 3, 2, 7]
        case .americanFootball: [6, 3, 2, 1]
        case .cricket: [1, 2, 3, 4, 6]
        default: [1]
        }
    }

    public var symbolName: String {
        switch self {
        case .tennis: "tennisball.fill"
        case .basketball: "basketball.fill"
        case .football: "soccerball"
        case .rugby: "figure.rugby"
        case .netball: "sportscourt.fill"
        case .americanFootball: "figure.american.football"
        case .hockey: "hockey.puck.fill"
        case .volleyball: "volleyball.fill"
        case .cricket: "cricket.ball.fill"
        case .baseball: "baseball.fill"
        case .badminton: "figure.badminton"
        case .tableTennis: "figure.table.tennis"
        case .golf: "figure.golf"
        case .handball: "figure.handball"
        case .boxing: "figure.boxing"
        case .cardGames: "suit.spade.fill"
        case .custom: "slider.horizontal.3"
        }
    }

    public var definition: SportDefinition {
        SportDefinition(
            id: rawValue,
            name: displayName,
            symbolName: symbolName,
            intervalSingular: intervalSingular,
            intervalPlural: intervalPlural,
            scoreValues: scoreValues
        )
    }
}

/// The sport for a game, including optional names chosen by the user.
public struct SportSelection: Codable, Equatable {
    public var definition: SportDefinition
    public var customName: String
    public var customIntervalSingular: String
    public var customIntervalPlural: String
    public var customScoreValues: [Int]

    public init(
        preset: SportPreset,
        customName: String = "",
        customIntervalSingular: String = "",
        customIntervalPlural: String = "",
        customScoreValues: [Int] = []
    ) {
        self.init(
            definition: preset.definition,
            customName: customName,
            customIntervalSingular: customIntervalSingular,
            customIntervalPlural: customIntervalPlural,
            customScoreValues: customScoreValues
        )
    }

    public init(
        definition: SportDefinition,
        customName: String = "",
        customIntervalSingular: String = "",
        customIntervalPlural: String = "",
        customScoreValues: [Int] = []
    ) {
        self.definition = definition
        self.customName = customName
        self.customIntervalSingular = customIntervalSingular
        self.customIntervalPlural = customIntervalPlural
        self.customScoreValues = customScoreValues
    }

    public var sportID: String { definition.id }

    /// Non-nil for selections from the original bundled sport list.
    public var preset: SportPreset? { SportPreset(rawValue: definition.id) }

    public var displayName: String {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        return sportID == SportPreset.custom.rawValue && !name.isEmpty ? name : definition.name
    }

    public var intervalSingular: String {
        let term = customIntervalSingular.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? definition.intervalSingular : term
    }

    public var intervalPlural: String {
        let term = customIntervalPlural.trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty { return term }
        if customIntervalSingular.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return definition.intervalPlural
        }
        if intervalSingular.lowercased() == "half" { return "Halves" }
        if intervalSingular.lowercased() == "innings" { return "Innings" }
        return "\(intervalSingular)s"
    }

    public func intervalName(number: Int) -> String {
        "\(intervalSingular) \(number)"
    }

    public var scoreValues: [Int] {
        guard !customScoreValues.isEmpty,
              customScoreValues.allSatisfy({ $0 > 0 }),
              Set(customScoreValues).count == customScoreValues.count else {
            return definition.scoreValues
        }
        return customScoreValues
    }

    private enum CodingKeys: String, CodingKey {
        case definition, preset, customName, customIntervalSingular, customIntervalPlural, customScoreValues
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let storedDefinition = try container.decodeIfPresent(SportDefinition.self, forKey: .definition) {
            definition = storedDefinition
        } else {
            // Preferences saved before remote catalogs used the enum name.
            definition = try container.decode(SportPreset.self, forKey: .preset).definition
        }
        customName = try container.decode(String.self, forKey: .customName)
        customIntervalSingular = try container.decode(String.self, forKey: .customIntervalSingular)
        customIntervalPlural = try container.decode(String.self, forKey: .customIntervalPlural)
        customScoreValues = try container.decodeIfPresent([Int].self, forKey: .customScoreValues) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(definition, forKey: .definition)
        try container.encode(customName, forKey: .customName)
        try container.encode(customIntervalSingular, forKey: .customIntervalSingular)
        try container.encode(customIntervalPlural, forKey: .customIntervalPlural)
        try container.encode(customScoreValues, forKey: .customScoreValues)
    }

    /// A string suitable for AppStorage and WatchConnectivity preferences.
    public var storageValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    public init?(storageValue: String) {
        guard let data = storageValue.data(using: .utf8),
              let selection = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }
        self = selection
    }
}

public enum SportStorageKeys {
    public static let defaultSelection = "defaultSportSelection"
    public static let currentSelection = "currentSportSelection"
}
