import SwiftUI

/// A view modifier that applies a ripple effect with chromatic aberration
struct RippleEffectModifier: ViewModifier {
    var trigger: Int
    var tapLocation: CGPoint
    var bounds: CGSize

    @State private var animationTime: CGFloat = 0
    @State private var isAnimating: Bool = false
    @State private var startDate: Date = Date()

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0, paused: !isAnimating)) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let progress = min(elapsed / 0.6, 1.0)

            content
                .visualEffect { content, proxy in
                    content
                        .layerEffect(
                            ShaderLibrary.rippleEffect(
                                .float(progress),
                                .float2(
                                    tapLocation.x / max(bounds.width, 1),
                                    tapLocation.y / max(bounds.height, 1)
                                ),
                                .float(max(bounds.width, 1) / max(bounds.height, 1))
                            ),
                            maxSampleOffset: CGSize(width: 20, height: 20)
                        )
                }
                .onChange(of: trigger) { oldValue, newValue in
                    // Start animation
                    startDate = Date()
                    isAnimating = true

                    // Stop after duration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isAnimating = false
                    }
                }
        }
    }
}

/// A conditional wrapper that only applies the ripple effect when enabled
struct ConditionalRippleEffect: ViewModifier {
    var isEnabled: Bool
    var trigger: Int
    var tapLocation: CGPoint
    var bounds: CGSize

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .modifier(RippleEffectModifier(trigger: trigger, tapLocation: tapLocation, bounds: bounds))
        } else {
            content
        }
    }
}

extension View {
    /// Applies a ripple effect with chromatic aberration when triggered
    /// - Parameters:
    ///   - trigger: A value that changes to trigger the effect
    ///   - location: The center point of the ripple in view coordinates
    ///   - bounds: The size of the view
    func rippleEffect(trigger: Int, at location: CGPoint, bounds: CGSize) -> some View {
        self.modifier(RippleEffectModifier(trigger: trigger, tapLocation: location, bounds: bounds))
    }
}
