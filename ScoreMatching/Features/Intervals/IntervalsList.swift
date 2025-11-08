import Foundation
import WhatScoreKit
import SwiftUI
import SwiftData

struct IntervalsList: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.watchSyncCoordinator) var watchSyncCoordinator
    @Query(sort: \Interval.date) var intervals: [Interval]
    @Query(sort: \Team.creationDate) var teams: [Team]

    @State private var showingNamePrompt = false
    @State private var newIntervalName = ""

    var body: some View {
        NavigationView {
            List {
                if intervals.isEmpty {
                    ContentUnavailableView(
                        "No Intervals Yet",
                        systemImage: "clock.badge.checkmark",
                        description: Text("Tap 'New Interval' to mark the end of a quarter, half, or period")
                    )
                } else {
                    ForEach(Array(intervals.enumerated()), id: \.element.id) { index, interval in
                        IntervalRowView(
                            interval: interval,
                            previousInterval: index > 0 ? intervals[index - 1] : nil
                        )
                    }
                    .onDelete { indexSet in
                        indexSet.forEach {
                            modelContext.delete(intervals[$0])
                        }
                        // Sync to watch after deleting intervals
                        do {
                            try modelContext.save()
                            print("📱 iOS IntervalsList: Deleted intervals, syncing to watch...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                watchSyncCoordinator?.sendData()
                            }
                        } catch {
                            print("❌ iOS IntervalsList: Failed to save after deleting intervals: \(error)")
                        }
                    }
                }

                Section {
                    Button {
                        showingNamePrompt = true
                    } label: {
                        Label("New Interval", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Intervals")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Name this interval", isPresented: $showingNamePrompt) {
                TextField("e.g., Q1, Half 1, Period 1", text: $newIntervalName)
                Button("Cancel", role: .cancel) {
                    newIntervalName = ""
                }
                Button("Create") {
                    createInterval()
                }
            } message: {
                Text("Give this interval a name to help identify it")
            }
        }
    }

    private func createInterval() {
        let name = newIntervalName.isEmpty ? "Interval \(intervals.count + 1)" : newIntervalName
        let interval = Interval.create(name: name, from: teams)
        modelContext.insert(interval)
        newIntervalName = ""

        // Immediately sync to watch after creating interval
        do {
            try modelContext.save()
            print("📱 iOS IntervalsList: Created interval '\(name)', syncing to watch...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                watchSyncCoordinator?.sendData()
            }
        } catch {
            print("❌ iOS IntervalsList: Failed to save after creating interval: \(error)")
        }
    }
}

struct IntervalRowView: View {
    let interval: Interval
    let previousInterval: Interval?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(interval.name)
                    .font(.headline)
                Spacer()
                Text(interval.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Show score breakdown
            VStack(alignment: .leading, spacing: 4) {
                ForEach(interval.teamSnapshots, id: \.teamName) { snapshot in
                    HStack {
                        Circle()
                            .fill(Color(hex: snapshot.teamColor))
                            .frame(width: 12, height: 12)
                        Text(snapshot.teamName)
                            .font(.subheadline)
                        Spacer()
                        Text("\(snapshot.totalScore)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        // Show score gained in this interval
                        if let scoreGained = interval.scoreGained(previousInterval: previousInterval)[snapshot.teamName] {
                            Text("(+\(scoreGained))")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ModelContainerPreview {
        IntervalsList()
    } modelContainer: {
        try makeModelContainer()
    }
}
