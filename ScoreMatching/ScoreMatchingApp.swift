import SwiftUI

@main
struct ScoreMatchingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

extension Color {
    static var random: Color {
        Color(hue: Double.random(in: (0...1)), saturation: Double.random(in: (0.8...1.0)), brightness: 1)
    }
}
