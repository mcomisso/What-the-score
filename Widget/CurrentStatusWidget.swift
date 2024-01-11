import WidgetKit
import SwiftUI
import SwiftData

struct Provider: TimelineProvider {
    @Query(sort: \Team.creationDate) var teams: [Team]
    @Environment(\.modelContext) var modelContext

    func placeholder(in context: Context) -> SimpleEntry {
        if teams.isEmpty {
            let teamA = Team(name: "Team A")
            let teamB = Team(name: "Team B")
            return SimpleEntry(date: Date(), teams: [teamA, teamB])
        }
        return SimpleEntry(date: Date(), teams: teams)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), teams: teams)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []
        let teamsEntries = SimpleEntry(
            date: Date(),
            teams: teams
        )
        entries.append(teamsEntries)
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let teams: [Team]
}

struct WidgetEntryView : View {
    @Query var teams: [Team]
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 0) {
            ForEach(teams) { team in
                team.resolvedColor
                    .overlay {
                        VStack{
                            Text(team.name)
                                .font(.subheadline)
                            Text("\(team.score.count)")
                                .font(
                                    .system(.title, design: .rounded)
                                )
                        }
                        .foregroundColor(team.resolvedColor)
                        .colorInvert()
                    }
            }
        }
    }
}

@main
struct CurrentStatusWidget: Widget {

    let kind: String = "Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
                .modelContainer(for: [Team.self])
        }
        .contentMarginsDisabled()
        .supportedFamilies([.systemSmall, .systemMedium])
        .configurationDisplayName("Current game")
        .description("Displays the current score for all teams.")
    }
}

#Preview {
    WidgetEntryView(entry: .init(date: .now, teams: []))
}
