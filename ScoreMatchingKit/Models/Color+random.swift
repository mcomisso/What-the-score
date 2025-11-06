import Foundation
import SwiftUI

public extension Color {
    static var random: Color {
        Color(hue: Double.random(in: (0...1)),
              saturation: Double.random(in: (0.6...0.8)),
              brightness: 0.8)
    }
}
