import Foundation
import SwiftUI
import SwiftData

struct IntervalsList: View {
    
    @Query var intervals: [Interval]
    @Environment(\.modelContext) var modelContext

    @Query var teams: [Team]

    var body: some View {
        List {
            ForEach(intervals) { interval in
                VStack(alignment: .center) {
                    Text("Interval \(intervals.count)")
//                        HStack {
//                            ForEach(intervals[interval].points.map { $0.count }, id: \.self) { points in
//                                Text("\(points)")
//                                    .font(.title)
//                                    .foregroundStyle(.secondary)
//                            }
//                    }
                }
            }
//            .onDelete { indexSet in
//                indexSet.forEach { modelContext.delete($0) }
//            }

            Section {
                Button("New interval") {
                    let interval = Interval(teams: teams, duration: 10)
                    modelContext.insert(interval)
                }
            }
        }
    }
}
