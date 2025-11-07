import SwiftUI
import SwiftData
import ScoreMatchingKit

struct IntervalsListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Query(sort: \Interval.date) var intervals: [Interval]

    @State private var showingCreatePrompt = false
    @State private var newIntervalName = ""

    var body: some View {
        NavigationStack {
            Group {
                if intervals.isEmpty {
                    emptyStateView
                } else {
                    intervalsList
                }
            }
            .navigationTitle("Intervals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreatePrompt = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Name Interval", isPresented: $showingCreatePrompt) {
                TextField("e.g., Q1, Half 1", text: $newIntervalName)
                Button("Cancel", role: .cancel) {
                    newIntervalName = ""
                }
                Button("Create") {
                    createInterval()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Intervals")
                .font(.headline)

            Text("Tap + to create")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Intervals List

    private var intervalsList: some View {
        List {
            ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
                let previousInterval = index > 0 ? intervals[index - 1] : nil

                VStack(alignment: .leading, spacing: 8) {
                    // Interval name
                    Text(interval.name)
                        .font(.headline)

                    // Team scores
                    ForEach(interval.teamSnapshots, id: \.teamName) { snapshot in
                        let scoreGained = interval.scoreGained(previousInterval: previousInterval)[snapshot.teamName] ?? 0

                        HStack {
                            Circle()
                                .fill(Color(hex: snapshot.teamColor))
                                .frame(width: 12, height: 12)

                            Text(snapshot.teamName)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            // Show points gained for this interval
                            if scoreGained != 0 {
                                Text("+\(scoreGained)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Text("\(snapshot.totalScore)")
                                .font(.caption)
                                .bold()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Actions

    private func createInterval() {
        let name = newIntervalName.isEmpty ? "Interval \(intervals.count + 1)" : newIntervalName
        let interval = Interval.create(name: name, from: teams)
        modelContext.insert(interval)
        newIntervalName = ""
    }
}

#Preview {
    IntervalsListView()
        .modelContainer(for: [Team.self, Interval.self], inMemory: true)
}
