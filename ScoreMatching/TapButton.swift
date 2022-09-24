import Foundation
import SwiftUI

struct TapButton: View {

    @Binding var score: [Score]
    @Binding var color: Color
    @Binding var name: String
    @Binding var lastTapped: String?
    @Binding var lastTimeTapped: Date

    var isEnabled: Bool = true

    private let feedbackGenerator = UIImpactFeedbackGenerator()
    private let warningGenerator = UINotificationFeedbackGenerator()

    @State var shadowRadius: Double = 10

    @State var isEditing: Bool = false
    @State var animationOffset: CGFloat = 0
    @State var animationAlpha: Double = 0
    @State var justAdded: Bool = false {
        didSet {
            if justAdded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    justAdded = false
                }
                animationAlpha = 1
                withAnimation(Animation.easeOut(duration: 0.7)) {
                    animationOffset = -150
                    animationAlpha = 0
                }
            } else {
                animationOffset = 0
            }

        }
    }

    var body: some View {
        ZStack {
            GeometryReader { geometryProxy in
                VStack {
                    let fontSize = min(geometryProxy.size.width, geometryProxy.size.height) / 3.5
                    Text("\(score.count)")
                        .font(.system(size: fontSize, design: .rounded))
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity)
                    Text(name)
                        .bold()
                        .font(.system(.headline, design: .default))
                        .padding(.bottom)
                }
                .foregroundStyle(color)
                .colorInvert()
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: didTapOnButton)
                .gesture(DragGesture().onEnded(onGestureEnd))

                if justAdded {
                    Text("+1")
                        .font(.largeTitle)
                        .offset(x: 100, y: animationOffset)
                        .opacity(animationAlpha)
                }
            }
        }
    }

    private func onGestureEnd(_ value: DragGesture.Value) {
        if !score.isEmpty {
            score.removeLast()
            feedbackGenerator.prepare()
            feedbackGenerator.impactOccurred()
            self.lastTimeTapped = Date()
        } else {
            warningGenerator.notificationOccurred(.warning)
        }
    }

    private func didTapOnButton() {
        if isEnabled {
            justAdded = true
            score.append(.init(time: .init()))
            feedbackGenerator.prepare()
            feedbackGenerator.impactOccurred()
            self.lastTapped = name
            self.lastTimeTapped = Date()
        }
    }
}
struct Previews_TapButton_Previews: PreviewProvider {
    @State static var score: [Score] = [Date()].map { Score.init(time: $0) }
    static var previews: some View {
        TapButton(
            score: $score,
            color: .constant(.primary),
            name: .constant("Team Name"),
            lastTapped: .constant(""),
            lastTimeTapped: .constant(Date())
        )
        .background(.gray)
    }
}
