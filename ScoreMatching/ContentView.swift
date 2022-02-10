import SwiftUI

class ViewModel: ObservableObject, Equatable {
    static func == (lhs: ViewModel, rhs: ViewModel) -> Bool {
        lhs.teamsViewModels == rhs.teamsViewModels
    }

    @Published var teamsViewModels: [TeamsData] = []

    @Published var intervals: [Interval] = []

    init() {
        teamsViewModels = ["Team A", "Team B"]
            .compactMap(TeamsData.init(_:))
    }

    func addInterval() {
        let copy = teamsViewModels
        let interval = Interval(id: 0, points: copy)
        intervals.append(interval)
    }

    func removeInterval(_ index: Int) {
        intervals.remove(at: index)
    }
}

struct Interval {
    var id: Int
    var points: [TeamsData]
}

struct CodableTeamData: Codable {
    let name: String
    let color: Color
    let count: Int
}

extension CodableTeamData: Identifiable {
    var id: String { name }
}

class TeamsData: ObservableObject, Identifiable, Equatable {
    static func == (lhs: TeamsData, rhs: TeamsData) -> Bool {
        lhs.id == rhs.id &&
        lhs.count == rhs.count &&
        lhs.name == rhs.name
    }

    let id: UUID = UUID()
    var count: Int = 0
    @Published var name: String
    @Published var color: Color = .random

    init(_ name: String) {
        self.name = name
    }

    func toCodable() -> CodableTeamData {
        .init(name: name, color: color, count: count)
    }
}

struct ContentView: View {
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @EnvironmentObject var connectivity: Connectivity

    @StateObject var viewModel = ViewModel()
    @State var lastTapped: String?
    @State var lastTimeTapped: Date = Date()

    @State var isVisualisingSettings: Bool = false
    @State var isShowingIntervals: Bool = false

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

            let encoder = JSONEncoder()
            if let encodedData = try? encoder.encode(data) {
                connectivity.send(data: encodedData)
            }
        })
        .sheet(isPresented: $isVisualisingSettings) {
            // Do nothing on dismiss
        } content: {
            SettingsView(teams: $viewModel.teamsViewModels)
        }
        .overlay(alignment: verticalSizeClass == .regular ? .center : .top) {
            VStack {
                if let lastTapped = lastTapped {
                    Text("Last scored: \(lastTapped)")
                        .font(.caption)
                } else {
                    Label("Intervals", systemImage: "timer")
                }

                if isShowingIntervals {

                    List {
                        ForEach(viewModel.intervals.indices, id: \.self) { intervalIdx in
                            VStack(alignment: .leading) {
                                Text("Interval \(intervalIdx)")

                                Text("\(viewModel.intervals[intervalIdx].points.map { $0.count }.description)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }.onDelete { indexSet in
                            viewModel.removeInterval(indexSet.first!)
                        }

                        Section {
                            Button("New interval") {
                                viewModel.addInterval()
                            }
                        }
                    }.listStyle(DefaultListStyle())
                }
            }.frame(maxWidth: 200)
                .padding()
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
                .shadow(radius: 16)
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
                    .foregroundColor(.primary)
                    .imageScale(.large)
                    .symbolRenderingMode(.hierarchical)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
            }
            Spacer()

            Button {
                isVisualisingSettings.toggle()
            } label: {
                Image(systemName: "gear")
                    .foregroundColor(.primary)
                    .imageScale(.large)
                    .symbolRenderingMode(.hierarchical)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
            }
        }
    }
    var buttons: some View {
        ForEach($viewModel.teamsViewModels) { team in
            TapButton(count: team.count, color: team.color, name: team.name, lastTapped: $lastTapped, lastTimeTapped: $lastTimeTapped)
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
        Group {
            ContentView()
            ContentView()
                .previewInterfaceOrientation(.landscapeLeft)
        }
    }
}
