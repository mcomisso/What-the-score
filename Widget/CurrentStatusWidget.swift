import SwiftUI
import SwiftData
import WhatScoreKit
import AppIntents

#if canImport(WidgetKit)
import WidgetKit

// MARK: - App Intent for Incrementing Scores

struct IncrementScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Increment Score"
    static var description = IntentDescription("Increments the score for a team")

    @Parameter(title: "Team Name")
    var teamName: String

    init() {}

    init(teamName: String) {
        self.teamName = teamName
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        // Access CloudKit synced data (same container as main app)
        let schema = Schema([Team.self, Interval.self, Game.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.mcsoftware.whatTheScore"),
            cloudKitDatabase: .private("iCloud.com.mcomisso.ScoreMatching")
        )
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = ModelContext(modelContainer)

        // Find the team
        let descriptor = FetchDescriptor<Team>(
            predicate: #Predicate { team in
                team.name == teamName
            }
        )

        guard let team = try context.fetch(descriptor).first else {
            throw IncrementScoreError.teamNotFound
        }

        // Increment the score
        team.score.append(Score(time: .now, value: 1))

        try context.save()

        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()

        return .result(value: true)
    }
}

enum IncrementScoreError: Error {
    case teamNotFound
}

// MARK: - Timeline Provider

struct Provider: AppIntentTimelineProvider {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([Team.self, Interval.self, Game.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.mcomisso.ScoreMatching")
            )
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private func fetchTeams() -> [Team] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)])
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch teams: \(error)")
            return []
        }
    }

    func placeholder(in context: Context) -> SimpleEntry {
        let teamA = Team(name: "Team A")
        let teamB = Team(name: "Team B")
        return SimpleEntry(date: Date(), teams: [teamA, teamB], configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let teams = fetchTeams()
        return SimpleEntry(date: Date(), teams: teams, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let teams = fetchTeams()
        let entry = SimpleEntry(date: Date(), teams: teams, configuration: configuration)
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let teams: [Team]
    let configuration: ConfigurationAppIntent
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description = IntentDescription("Widget Configuration")
}

struct WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entry.teams) { team in
                Button(intent: IncrementScoreIntent(teamName: team.name)) {
                    team.resolvedColor
                        .overlay {
                            VStack {
                                Text(team.name)
                                    .font(.subheadline)
                                Text("\(team.score.safeTotalScore)")
                                    .font(.system(.title, design: .rounded))
                            }
                            .foregroundColor(team.resolvedColor)
                            .colorInvert()
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

@main
struct CurrentStatusWidget: Widget {

    let kind: String = "Widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
                .modelContainer(for: [Team.self, Interval.self, Game.self])
        }
        .contentMarginsDisabled()
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Current game")
        .description("Tap teams to increment their score.")
    }
}

#Preview {
    WidgetEntryView(entry: .init(date: .now, teams: [], configuration: ConfigurationAppIntent()))
}
#endif
