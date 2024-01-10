import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @EnvironmentObject var connectivity: Connectivity

    @AppStorage("encodedTeamData", store: UserDefaults(suiteName: "group.mcomisso.whatTheScore"))
    var encodedTeamsData: Data = Data()

    @Query(sort: \Team.name) var teams: [Team]

    @State private var viewModel = ViewModel()
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
        .onChange(of: lastTimeTapped, perform: { _ in

            let data = self.viewModel.teamsViewModels.map { $0.toCodable() }

            guard let encodedData = try? JSONEncoder().encode(data) else {
                return
            }
            print(encodedData.description)
            connectivity.send(data: encodedData)
            encodedTeamsData = encodedData
        })
        .sheet(isPresented: $isVisualisingSettings, onDismiss: nil, content: {
            SettingsView(teams: $viewModel.teamsViewModels)
        })
        .sheet(isPresented: $isShowingIntervals, onDismiss: nil, content: {
            IntervalsList(viewModel: self.viewModel)
        })
        .overlay(alignment: .top) {
            FloaterText(text: $lastTapped)
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
            .contextMenu {
                Text("Current interval: \(viewModel.intervals.count)")
                Button("Start new") {
                    viewModel.addInterval()
                }
            }
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
        }.symbolRenderingMode(.hierarchical)
    }

    var buttons: some View {
        ForEach($viewModel.teamsViewModels) { team in
            TapButton(
                score: team.score,
                color: team.color,
                name: team.name,
                lastTapped: $lastTapped,
                lastTimeTapped: $lastTimeTapped
            )
            .background(team.color.wrappedValue)
            .id(team.name.wrappedValue)
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
