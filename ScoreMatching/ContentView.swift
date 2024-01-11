import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(Connectivity.self) var connectivity

    @Query(sort: \Team.creationDate) var teams: [Team]
    @Environment(\.modelContext) var modelContext

    @State private var lastTapped: String?
    @State private var lastTimeTapped: Date = Date()

    @State private var isVisualisingSettings: Bool = false
    @State private var isShowingIntervals: Bool = false

    @State private var shadowRadius: Double = 10

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
        .onChange(of: lastTimeTapped, { _, _ in
            let data = teams.map { $0.toCodable() }

            guard let encodedData = try? JSONEncoder().encode(data) else {
                return
            }
            print(encodedData.description)
            connectivity.send(data: encodedData)
        })
        .sheet(isPresented: $isVisualisingSettings, onDismiss: nil, content: {
            SettingsView()
        })
//        .sheet(isPresented: $isShowingIntervals, onDismiss: nil, content: {
//            IntervalsList(viewModel: self.viewModel)
//        })
//        .overlay(alignment: .top) {
//            FloaterText(text: $lastTapped)
//        }
        .onAppear {
            if teams.isEmpty {
                Team.createBaseData(modelContext: modelContext)
            }
        }
    }

    var bottomToolbar: some View {
        HStack {
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
//            .contextMenu {
//                Text("Current interval: \(viewModel.intervals.count)")
//                Button("Start new") {
//                    viewModel.addInterval()
//                }
//            }
            .featureFlag(.intervalsFeature)

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
                Button(role: .destructive) {
                    teams.forEach { modelContext.delete($0) }
                    Team.createBaseData(modelContext: modelContext)
                } label: {
                    Label("Reset", systemImage: "trash")
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
                lastTapped: $lastTapped,
                lastTimeTapped: $lastTimeTapped
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
