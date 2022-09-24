import SwiftUI

struct FloaterText: View {

    @Binding var text: String?

    var body: some View {
        if let text = text {
            VStack {
                Text(text)
                    .font(.subheadline)
            }.padding()
                .background(.thickMaterial,
                            in: RoundedRectangle(cornerRadius: 16))
                .padding()
                .shadow(radius: 16)
        } else {
            EmptyView()
        }
    }
}

enum FeatureFlag: String {
    case intervalsFeature
    case exportScorecard

    var isActive: Bool {
        UserDefaults.standard.bool(forKey: self.rawValue)
    }
}

extension View {
    func featureFlag(_ featureFlag: FeatureFlag) -> some View {
        self.modifier(FeatureFlagModifier(featureFlag))
    }
}

struct FeatureFlagModifier: ViewModifier {

    private var featureFlag: FeatureFlag

    init(_ featureFlag: FeatureFlag) {
        self.featureFlag = featureFlag
    }

    func body(content: Content) -> some View {
        if featureFlag.isActive {
            content
        } else {
            content
                .hidden()
        }
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
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
            }
        }.symbolRenderingMode(.hierarchical)
    }
    @State var shadowRadius: Double = 10
    var buttons: some View {
        ForEach($viewModel.teamsViewModels) { team in
            TapButton(count: team.count, color: team.color, name: team.name,
                      lastTapped: $lastTapped, lastTimeTapped: $lastTimeTapped)
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
