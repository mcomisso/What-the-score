import SwiftUI

struct MainView: View {
    @SceneStorage("isReceiverMode")
    var isReceiverMode: Bool = false

    var body: some View {
        if isReceiverMode {
            ReceiverModeView(isReceiverMode: $isReceiverMode)
        } else {
            ContentView()
        }
    }
}

@main
struct ScoreMatchingApp: App {
    private let connectivity = Connectivity()
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(connectivity)
        }
    }
}

extension Color {
    static var random: Color {
        Color(hue: Double.random(in: (0...1)),
              saturation: Double.random(in: (0.6...0.8)),
              brightness: 0.9)
    }
}

