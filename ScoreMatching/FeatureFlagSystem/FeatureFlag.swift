import Foundation
import SwiftUI

extension View {
    func featureFlag(_ featureFlag: FeatureFlag) -> some View {
        self.modifier(FeatureFlagModifier(featureFlag))
    }
}

enum FeatureFlag: String {
    case intervalsFeature
    case exportScorecard

    var isActive: Bool {
        UserDefaults.standard.bool(forKey: self.rawValue)
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
