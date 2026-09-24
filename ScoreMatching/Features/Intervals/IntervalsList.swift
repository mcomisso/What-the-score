import Foundation
import WhatScoreKit
import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "IntervalsList")

struct IntervalsList: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.watchSyncCoordinator) var watchSyncCoordinator
    @Query(sort: \Interval.date) var intervals: [Interval]
    @Query(sort: \Team.creationDate) var teams: [Team]

    @AppStorage(SportStorageKeys.currentSelection)
    private var currentSportStorage = ""

    @State private var showingNamePrompt = false
    @State private var newIntervalName = ""

    private var currentSport: SportSelection {
        SportSelection(storageValue: currentSportStorage) ?? SportSelection(preset: .custom)
    }

    var body: some View {
        NavigationStack {
            List {
                if intervals.isEmpty {
                    ContentUnavailableView(
                        "No \(currentSport.intervalPlural) yet",
                        systemImage: "clock.badge.checkmark",
                        description: Text("Add \(currentSport.intervalName(number: 1)) to save the current scores")
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
                        Analytics.log(.intervalDeleted, with: ["remaining_intervals": "\(intervals.count - indexSet.count)"])
                        // Sync to watch after deleting intervals
                        do {
                            try modelContext.save()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                watchSyncCoordinator?.sendData()
                            }
                        } catch {
                            logger.error("Failed to save after deleting intervals: \(error.localizedDescription)")
                        }
                    }
                }

                Section {
                    Button {
                        showingNamePrompt = true
                    } label: {
                        Label("New \(currentSport.intervalSingular)", systemImage: "plus.circle.fill")
                    }
                }
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(currentSport.intervalPlural)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Name this \(currentSport.intervalSingular)", isPresented: $showingNamePrompt) {
                TextField(currentSport.intervalName(number: intervals.count + 1), text: $newIntervalName)
                Button("Cancel", role: .cancel) {
                    newIntervalName = ""
                }
                Button("Create") {
                    createInterval()
                }
            } message: {
                Text("You can edit the suggested name")
            }
        }
    }

    private func createInterval() {
        let name = newIntervalName.isEmpty ? currentSport.intervalName(number: intervals.count + 1) : newIntervalName
        let interval = Interval.create(name: name, from: teams)
        modelContext.insert(interval)
        newIntervalName = ""
        Analytics.log(.intervalCreated, with: ["interval_count": "\(intervals.count + 1)", "source": "intervals_list"])

        // Immediately sync to watch after creating interval
        do {
            try modelContext.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                watchSyncCoordinator?.sendData()
            }
        } catch {
            logger.error("Failed to save after creating interval: \(error.localizedDescription)")
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
