import SwiftUI

class ViewModel: ObservableObject {
    @Published var teamsViewModels: [TeamsData] = []

    init() {
        teamsViewModels = ["Team A", "Team B"]
            .compactMap(TeamsData.init(_:))
    }

    func resetScores() {
        teamsViewModels
            .forEach { team in
                team.count = 0
            }
    }

    func newGame() {
        teamsViewModels = ["Team A", "Team B"]
            .compactMap(TeamsData.init(_:))
    }
}

class TeamsData: ObservableObject, Identifiable {
    let id: UUID = UUID()
    var count: Int = 0
    @Published var name: String
    @Published var color: Color = .random

    init(_ name: String) {
        self.name = name
    }
}

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @StateObject var viewModel = ViewModel()

    @State var isVisualisingSettings: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.ignoresSafeArea()

            if verticalSizeClass == .regular {
                // Portrait
                VStack(spacing: 0) {
                    ForEach($viewModel.teamsViewModels) { team in
                        TapButton(count: team.count, color: team.color, name: team.name)
                            .background(team.color.wrappedValue).id(team.name.wrappedValue)
                    }
                }.ignoresSafeArea()
            } else if verticalSizeClass == .compact {
                // Landscape
                HStack(spacing: 0) {
                    ForEach($viewModel.teamsViewModels) { team in
                        TapButton(count: team.count, color:  team.color, name: team.name)
                            .background(team.color.wrappedValue).id(team.name.wrappedValue)
                    }
                }.ignoresSafeArea()
            }

            Button {
                isVisualisingSettings.toggle()
            } label: {
                Image(systemName: "gear")
                    .foregroundColor(.primary)
                    .imageScale(.large)
                    .symbolRenderingMode(.hierarchical)
                    .padding()
                    .shadow(radius: 10)
            }
            .ignoresSafeArea(.all, edges: .all)
                .padding()

        }
        .sheet(isPresented: $isVisualisingSettings) {
            // Do nothing on dismiss
        } content: {
            SettingsView(teams: $viewModel.teamsViewModels)
        }
        .overlay {
            ZStack {
                GeometryReader { reader in
                RoundedRectangle(cornerRadius: 16)
                    .fill(.primary)
                    .offset(x: verticalSizeClass == .compact ? 0 : -reader.size.width, y: verticalSizeClass == .compact ? -reader.size.height : 0)
                }
            }

        }

    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
            ContentView()
                .previewInterfaceOrientation(.landscapeLeft)
        }
    }
}
