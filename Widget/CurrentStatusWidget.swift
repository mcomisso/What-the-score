import SwiftUI
import SwiftData
#if canImport(WidgetKit)
import WidgetKit

struct Provider: TimelineProvider {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([Team.self, Interval.self, Game.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier("group.mcomisso.whatTheScore")
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
        return SimpleEntry(date: Date(), teams: [teamA, teamB])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let teams = fetchTeams()
        let entry = SimpleEntry(date: Date(), teams: teams)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let teams = fetchTeams()
        let entry = SimpleEntry(date: Date(), teams: teams)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let teams: [Team]
}

struct WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entry.teams) { team in
                team.resolvedColor
                    .overlay {
                        VStack{
                            Text(team.name)
                                .font(.subheadline)
                            Text("\(team.score.safeTotalScore)")
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
                .modelContainer(for: [Team.self, Interval.self, Game.self])
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
#endif
