import Foundation
import SwiftData
import SwiftUI

@Model
public class Team {
    var score: [Score] = []
    var name: String = ""
    var color: ColorComponents = ColorComponents(red: 0, green: 0, blue: 0)

    init(score: [Score], name: String, color: ColorComponents) {
        self.score = score
        self.name = name
        self.color = color
    }

    func toCodable() -> CodableTeamData {
        .init(name: name, color: color.color, score: score)
    }
}

struct ColorComponents: Codable {
    let red: Float
    let green: Float
    let blue: Float

    var color: Color {
        Color(red: Double(red), green: Double(green), blue: Double(blue))
    }

    static func fromColor(_ color: Color) -> ColorComponents {
        let resolved = color.resolve(in: EnvironmentValues())
        return ColorComponents(
            red: resolved.red,
            green: resolved.green,
            blue: resolved.blue
        )
    }
}
