import Foundation
import SwiftUI

struct TapButton: View {

    @Binding var count: Int
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
                    Text("\(count)")
                        .font(.system(size: min(geometryProxy.size.width, geometryProxy.size.height) / 3.5))
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity)
                    Text(name)
                        .bold()
                        .font(.headline)
                        .padding(.bottom)
                }
                .foregroundColor(color)
                .colorInvert()
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isEnabled {
                        justAdded = true
                        count += 1
                        feedbackGenerator.prepare()
                        feedbackGenerator.impactOccurred()
                        self.lastTapped = name
                        self.lastTimeTapped = Date()
                    }
                }
                .gesture(DragGesture()
                            .onEnded { valuee in
                    if count > 0 {
                        count -= 1
                        feedbackGenerator.prepare()
                        feedbackGenerator.impactOccurred()
                        self.lastTimeTapped = Date()
                    } else {
                        warningGenerator.notificationOccurred(.warning)
                    }
                })

                if justAdded {
                    Text("+1")
                        .font(.largeTitle)
                        .offset(x: 100, y: animationOffset)
                        .opacity(animationAlpha)
                }
            }
        }
    }
}
struct Previews_TapButton_Previews: PreviewProvider {
    @State static var count: Int = 0
    static var previews: some View {
        TapButton(count: $count, color: .constant(.primary), name: .constant("Team Name"), lastTapped: .constant(""), lastTimeTapped: .constant(Date()))
            .background(.gray)
    }
}
