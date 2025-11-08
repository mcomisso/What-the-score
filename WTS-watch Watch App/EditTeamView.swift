import Foundation
import WhatScoreKit
import SwiftUI
import SwiftData

struct EditTeamView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.watchSyncCoordinator) var watchSyncCoordinator

    @Bindable var team: Team

    // Preset colors for watchOS
    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown,
        .gray
    ]

    var body: some View {
        List {
            Section("Team Name") {
                TextField("Team name", text: $team.name)
                    .onChange(of: team.name) { _, _ in
                        syncToPhone()
                    }
            }

            Section("Team Color") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                    ForEach(presetColors.indices, id: \.self) { index in
                        let color = presetColors[index]
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay {
                                if isColorSimilar(color, to: team.resolvedColor) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.white)
                                        .font(.body.bold())
                                }
                            }
                            .onTapGesture {
                                team.resolvedColor = color
                                syncToPhone()
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Edit Team")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isColorSimilar(_ color1: Color, to color2: Color) -> Bool {
        // Simple comparison - check if colors are the same preset
        let env = EnvironmentValues()
        return color1.description == color2.description
    }

    private func syncToPhone() {
        // Debounce sync slightly to avoid too many updates while typing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            watchSyncCoordinator?.sendTeamDataToPhone()
        }
    }
}

#Preview {
    NavigationStack {
        EditTeamView(team: Team(name: "Team A"))
    }
    .modelContainer(for: [Team.self, Interval.self], inMemory: true)
}
