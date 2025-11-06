import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.modelContext) var modelContext

    @AppStorage(AppStorageValues.hasEnabledIntervals)
    var hasEnabledIntervals: Bool = false

    @Query(sort: \Team.creationDate) var teams: [Team]

    @State private var lastTapped: String?

    @State private var isVisualisingSettings: Bool = false
    @State private var isShowingIntervals: Bool = false

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
        .onAppear {
            if teams.isEmpty {
                Team.createBaseData(modelContext: modelContext)
            }
        }
    }

    var bottomToolbar: some View {
        HStack {
            if hasEnabledIntervals {
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

            Spacer()

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
