import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    @AppStorage("encodedTeamData")
    var encodedTeamsData: Data = Data()

    func placeholder(in context: Context) -> SimpleEntry {
        let teamA = TeamsData("Team A")
        let teamB = TeamsData("Team B")

        return SimpleEntry(date: Date(), teams: [teamA, teamB])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {

        do {
            let teamsDecodedData = try JSONDecoder()
                .decode([CodableTeamData].self, from: encodedTeamsData)

            let entry = SimpleEntry(date: Date(), teams: teamsDecodedData.map { $0.toTeamData() })

            completion(entry)
        } catch {
            completion(.init(date: Date(), teams: []))
        }

    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, teams: [])
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date

    let teams: [TeamsData]
}

struct WidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 0) {
            ForEach(entry.teams) { team in
                team.color
                    .overlay {
                        VStack{
                            Text(team.name)
                                .font(.subheadline)
                            Text("\(team.score.count)")
                                .font(
                                    .system(.title, design: .rounded)
                                )
                        }
                        .foregroundColor(team.color)
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
        }
        .configurationDisplayName("Current game")
        .description("Displays the current score for all teams.")
    }
}

struct Widget_Previews: PreviewProvider {
    static var previews: some View {
        WidgetEntryView(entry: SimpleEntry(date: Date(), teams: [.init("Team A"), .init("Team B")]))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
