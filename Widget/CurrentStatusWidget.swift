import SwiftUI
import SwiftData
import WhatScoreKit
import WhatScoreIntents
import AppIntents

#if canImport(WidgetKit)
import WidgetKit

// MARK: - Timeline Provider

struct Provider: AppIntentTimelineProvider {
    private func fetchTeams() async -> [WidgetTeam] {
        await MainActor.run {
            do {
                let context = ModelContext(try ScoreboardStore.makeContainer())
                try TeamIdentity.backfill(in: context)
                let teams = try context.fetch(FetchDescriptor<Team>(sortBy: [SortDescriptor(\.creationDate)]))
                return teams.compactMap(WidgetTeam.init(team:))
            } catch {
                print("Failed to fetch teams: \(error)")
                return []
            }
        }
    }

    func placeholder(in context: Context) -> SimpleEntry {
        let teamA = WidgetTeam(id: UUID(), name: "Team A", color: "FF0000", score: 0)
        let teamB = WidgetTeam(id: UUID(), name: "Team B", color: "0000FF", score: 0)
        return SimpleEntry(date: Date(), teams: [teamA, teamB], configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let teams = await fetchTeams()
        return SimpleEntry(date: Date(), teams: teams, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let teams = await fetchTeams()
        let entry = SimpleEntry(date: Date(), teams: teams, configuration: configuration)
        return Timeline(entries: [entry], policy: .atEnd)
    }
}

struct WidgetTeam: Identifiable, Sendable {
    let id: UUID
    let name: String
    let color: String
    let score: Int

    @MainActor
    init?(team: Team) {
        guard let id = team.shortcutID else { return nil }
        self.init(id: id, name: team.name, color: team.color, score: team.score.safeTotalScore)
    }

    init(id: UUID, name: String, color: String, score: Int) {
        self.id = id
        self.name = name
        self.color = color
        self.score = score
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let teams: [WidgetTeam]
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
                Button(intent: AddPointIntent(team: TeamEntity(id: team.id, name: team.name))) {
                    teamTile(for: team)
                }
                .buttonStyle(.plain)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private func teamTile(for team: WidgetTeam) -> some View {
        Color(hex: team.color)
            .overlay {
                VStack {
                    Text(team.name)
                        .font(.subheadline)
                    Text("\(team.score)")
                        .font(.system(.title, design: .rounded))
                }
                .foregroundStyle(Color(hex: team.color))
                .colorInvert()
            }
    }
}

struct CurrentStatusWidgetIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [WhatScoreIntentsPackage.self]
    }
}

@main
struct CurrentStatusWidget: Widget {

    let kind: String = "Widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
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
