import Foundation
import SwiftUI
import Pow

struct TapButton: View {

    @Binding var score: [Score]
    @Binding var colorHex: String
    @Binding var name: String
    @Binding var lastTapped: String?
    @Binding var lastTimeTapped: Date

    var isEnabled: Bool = true

    private let warningGenerator = UINotificationFeedbackGenerator()

    @State var shadowRadius: Double = 10

    @State var increased: Int = 0
    @State var decreased: Int = 0

    @State var justAdded: Bool = false

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
                .foregroundStyle(Color(hex: colorHex))
                .colorInvert()
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(perform: didTapOnButton)
                .gesture(DragGesture().onEnded(onGestureEnd))
                .sensoryFeedback(.increase, trigger: increased)
                .sensoryFeedback(.decrease, trigger: decreased)
                .changeEffect(
                    .rise(origin: UnitPoint(x: 0.75, y: 0.35)) {
                        Text("+1")
                            .foregroundStyle(Color(hex: colorHex))
                            .scaleEffect(x: 2, y: 2, anchor: .center)
                            .colorInvert()
                    }, value: justAdded)
            }
        }
    }

    private func onGestureEnd(_ value: DragGesture.Value) {
        if !score.isEmpty {
            score.removeLast()
            self.lastTimeTapped = Date()
            decreased += 1
        } else {
            warningGenerator.notificationOccurred(.warning)
        }
    }

    private func didTapOnButton() {
        if isEnabled {

            justAdded.toggle()
            score.append(.init(time: .init()))
            increased += 1
            self.lastTapped = name
            self.lastTimeTapped = Date()

        }
    }
}

#Preview("Tap button") {
    TapButton(
        score: .constant([Date()].map { Score(time: $0) }),
        colorHex: .constant(Color.primary.toHex()),
        name: .constant("Team Name"),
        lastTapped: .constant(""),
        lastTimeTapped: .constant(Date())
    )
    .background(.gray)
}
