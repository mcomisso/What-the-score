import Foundation
import SwiftUI
import SwiftData

struct IntervalsList: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Interval.duration) var intervals: [Interval]

    @Query var teams: [Team]

    var body: some View {
        List {
            ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
                VStack(alignment: .leading) {
                    Text(interval.date.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.secondary)
                    Text("Interval \(index + 1)")
                    // TODO: Display team scores for this interval once feature is complete
                }
            }
            .onDelete { indexSet in
                indexSet.forEach {
                    modelContext.delete(intervals[$0])
                }
            }

            Section {
                Button("New interval") {
                    let interval = Interval(teams: teams, duration: 10)
                    modelContext.insert(interval)
                }
            }
        }
    }
}

#Preview {
    ModelContainerPreview {
        IntervalsList()
    } modelContainer: {
        try makeModelContainer()
    }
}
