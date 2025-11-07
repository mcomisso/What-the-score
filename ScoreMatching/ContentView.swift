import SwiftUI
import SwiftData
import WhatScoreKit

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.modelContext) var modelContext
    @Environment(\.watchSyncCoordinator) var watchSyncCoordinator

    @AppStorage(AppStorageValues.hasEnabledIntervals)
    var hasEnabledIntervals: Bool = false

    @AppStorage(AppStorageValues.shouldAllowNegativePoints)
    var shouldAllowNegativePoints: Bool = false

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Query(sort: \Interval.date) var intervals: [Interval]

    @State private var lastTapped: String?

    @State private var isVisualisingSettings: Bool = false
    @State private var isShowingIntervals: Bool = false
    @State private var showingQuickIntervalPrompt: Bool = false
    @State private var quickIntervalName: String = ""

    // Track changes for sync
    @State private var lastSyncedTeamsCount: Int = 0
    @State private var lastSyncedScoresHash: Int = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if verticalSizeClass == .regular {
                portraitButtons
            } else if verticalSizeClass == .compact {
                landscapeButtons
            }

            bottomToolbar
                .ignoresSafeArea(.all, edges: .all)
                .padding()
        }
        .sheet(isPresented: $isShowingIntervals) {
            IntervalsList()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $isVisualisingSettings, onDismiss: nil, content: {
            SettingsView()
        })
        .alert("Name this interval", isPresented: $showingQuickIntervalPrompt) {
            TextField("e.g., Q1, Half 1", text: $quickIntervalName)
            Button("Cancel", role: .cancel) {
                quickIntervalName = ""
            }
            Button("Create") {
                createQuickInterval(name: quickIntervalName.isEmpty ? "Interval \(intervals.count + 1)" : quickIntervalName)
                quickIntervalName = ""
            }
        }
        .onChange(of: shouldAllowNegativePoints) { oldValue, newValue in
            // When negative points is disabled, remove all negative scores
            if !newValue {
                cleanupNegativeScores()
            }
        }
        .onAppear {
            if teams.isEmpty {
                Team.createBaseData(modelContext: modelContext)
            }
        }
        .onChange(of: teams.count) { _, _ in
            // Notify watch when teams are added/removed
            watchSyncCoordinator?.notifyDataChanged()
        }
        .onChange(of: teams.map { $0.score.count }) { _, _ in
            // Notify watch when scores change
            watchSyncCoordinator?.notifyDataChanged()
        }
        .onChange(of: intervals.count) { _, _ in
            // Notify watch when intervals change
            watchSyncCoordinator?.notifyDataChanged()
        }
    }

    private func cleanupNegativeScores() {
        for team in teams {
            team.score.removeNegativeScores()
        }
    }

    private func createQuickInterval(name: String) {
        let interval = Interval.create(name: name, from: teams)
        modelContext.insert(interval)
    }

    var bottomToolbar: some View {
        HStack {
            if hasEnabledIntervals {
                Group {
                    if #available(iOS 26.0, *) {
                        Button("Timer", systemImage: "timer") {
                            withAnimation(Animation.interactiveSpring()) {
                                isShowingIntervals.toggle()
                            }
                        }
                        .labelStyle(.iconOnly)
                        .imageScale(.large)
                        .controlSize(.large)
                        .buttonBorderShape(.circle)
                        .buttonStyle(.glass)
                    } else {
                        Button {
                            withAnimation(Animation.interactiveSpring()) {
                                isShowingIntervals.toggle()
                            }
                        } label: {
                            Image(systemName: "timer")
                                .foregroundStyle(.primary)
                                .imageScale(.large)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                                .shadow(radius: 8)
                        }
                    }
                }
                .contextMenu {
                    Button {
                        showingQuickIntervalPrompt = true
                    } label: {
                        Label("Quick Add Interval", systemImage: "plus.circle")
                    }

                    Button {
                        createQuickInterval(name: "Q\(intervals.count + 1)")
                    } label: {
                        Label("Add Q\(intervals.count + 1)", systemImage: "clock")
                    }
                }
            }

            Spacer()

            Group {
                if #available(iOS 26.0, *) {
                    Button("Settings", systemImage: "gear") {
                        isVisualisingSettings.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .controlSize(.large)
                    .buttonBorderShape(.circle)
                    .imageScale(.large)
                    .buttonStyle(.glass)
                } else {
                    Button {
                        isVisualisingSettings.toggle()
                    } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.primary)
                            .imageScale(.large)
                            .padding()
                            .background(.regularMaterial,
                                        in: RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 8)
                    }
                }
            }
            .contextMenu(menuItems: {
                Button {
                    teams.forEach { $0.score = [] }
                } label: {
                    Label("Set scores to 0", systemImage: "arrow.counterclockwise")
                }
                
                Divider()

                Button(role: .destructive) {
                    teams.forEach { modelContext.delete($0) }
                    Team.createBaseData(modelContext: modelContext)
                } label: {
                    Label("Reset all", systemImage: "trash")
                }
            })
        }.symbolRenderingMode(.hierarchical)
    }

    var buttons: some View {
        ForEach(teams) { team in
            @Bindable var bindingTeam = team
            TapButton(
                score: $bindingTeam.score,
                colorHex: $bindingTeam.color,
                name: $bindingTeam.name,
                lastTapped: $lastTapped
            )
            .background(Color(hex: team.color))
            .overlay(alignment: .leading) {
                if lastTapped == team.name {
                    Image(systemName: "arrowtriangle.right.fill")
                        .resizable()
                        .foregroundStyle(team.resolvedColor)
                        .frame(width: 32, height: 32)
                        .colorInvert()
                }
            }
        }
    }

    var landscapeButtons: some View {
        HStack(spacing: 0) {
            buttons
        }.ignoresSafeArea()
    }

    var portraitButtons: some View {
        VStack(spacing: 0) {
            buttons
        }.ignoresSafeArea()
    }

}


#Preview {
    ModelContainerPreview {
        ContentView()
    } modelContainer: {
        try makeModelContainer()
    }
}
