//
//  ContentView.swift
//  WTS-watch Watch App
//
//  Created by Matteo Comisso on 06/11/2025.
//

import SwiftUI
import SwiftData
import ScoreMatchingKit 

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Team.creationDate) var teams: [Team]
    @Query(sort: \Interval.date) var intervals: [Interval]

    @State private var isShowingSettings = false
    @State private var isShowingIntervals = false
    @State private var syncCoordinator: WatchSyncCoordinator?

    @AppStorage("shouldAllowNegativePoints") var shouldAllowNegativePoints: Bool = false
    @AppStorage("hasEnabledIntervals") var hasEnabledIntervals: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if teams.isEmpty {
                    emptyStateView
                } else if teams.count <= 4 {
                    singlePageView(teams: teams)
                } else {
                    paginatedView
                }
            }
            .navigationTitle("Scores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if hasEnabledIntervals {
                        Button {
                            isShowingIntervals = true
                        } label: {
                            Image(systemName: "timer")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $isShowingIntervals) {
                IntervalsListView()
            }
            .onAppear {
                if teams.isEmpty {
                    Team.createBaseData(modelContext: modelContext)
                }

                // Initialize sync coordinator
                if syncCoordinator == nil {
                    syncCoordinator = WatchSyncCoordinator(modelContext: modelContext)
                }
            }
            .onChange(of: teams.count) { _, _ in
                // Sync when teams change
                syncCoordinator?.syncTeamsToPhone()
            }
            .onChange(of: intervals.count) { _, _ in
                // Sync when intervals change
                syncCoordinator?.syncIntervalsToPhone()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No Teams")
                .font(.headline)

            Text("Add teams from Settings")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Single Page (1-4 teams)

    private func singlePageView(teams: [Team]) -> some View {
        VStack(spacing: 4) {
            if teams.count >= 2 {
                HStack(spacing: 4) {
                    teamButton(at: 0, in: teams)
                    if teams.count >= 2 {
                        teamButton(at: 1, in: teams)
                    }
                }
            } else if teams.count == 1 {
                teamButton(at: 0, in: teams)
            }

            if teams.count >= 3 {
                HStack(spacing: 4) {
                    teamButton(at: 2, in: teams)
                    if teams.count >= 4 {
                        teamButton(at: 3, in: teams)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Paginated View (>4 teams)

    private var paginatedView: some View {
        TabView {
            ForEach(pageIndices, id: \.self) { pageIndex in
                let startIdx = pageIndex * 4
                let endIdx = min(startIdx + 4, teams.count)
                let pageTeams = Array(teams[startIdx..<endIdx])

                singlePageView(teams: pageTeams)
            }
        }
        .tabViewStyle(.page)
        .ignoresSafeArea(edges: .bottom)
    }

    private var pageIndices: [Int] {
        let pageCount = (teams.count + 3) / 4
        return Array(0..<pageCount)
    }

    // MARK: - Team Button Helper

    @ViewBuilder
    private func teamButton(at index: Int, in teams: [Team]) -> some View {
        if index < teams.count {
            let team = teams[index]
            TeamButtonView(team: .constant(team)) {
                // Sync scores to iPhone when they change
                syncCoordinator?.syncTeamsToPhone()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Team.self, Interval.self, Game.self], inMemory: true)
}
