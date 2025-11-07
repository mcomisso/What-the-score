import Foundation
import WhatScoreKit
import SwiftUI
import SwiftData
import Pow

struct TapButton: View {
    @AppStorage(AppStorageValues.shouldAllowNegativePoints)
    var shouldAllowNegativePoints: Bool = false
    @Environment(\.modelContext) var modelContext

    @Binding var score: [Score]
    @Binding var colorHex: String
    @Binding var name: String
    @Binding var lastTapped: String?

    var isEnabled: Bool = true
    var onScoreChanged: (() -> Void)?
    #if os(iOS)
    private let warningGenerator = UINotificationFeedbackGenerator()
    #endif

    @State var increased: Int = 0
    @State var decreased: Int = 0

    @State var justAdded: Bool = false

    var body: some View {
        ZStack {
            GeometryReader { geometryProxy in
                VStack {
                    let fontSize = min(geometryProxy.size.width, geometryProxy.size.height) / 3.5
                    let displayScore = shouldAllowNegativePoints ? score.totalScore : score.safeTotalScore
                    Text("\(displayScore)")
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
                .onTapGesture {
                    didTapOnButton()
                }
                .gesture(DragGesture().onEnded(onGestureEnd))
                #if os(iOS)
                .sensoryFeedback(.increase, trigger: increased)
                .sensoryFeedback(.decrease, trigger: decreased)
                #endif
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
        if shouldAllowNegativePoints {
            score.append(Score(time: .now, value: -1))
            decreased += 1
            saveAndSync()
        } else {
            if !score.isEmpty {
                score.removeLast()
                decreased += 1
                saveAndSync()
            } else {
#if os(iOS)
                warningGenerator.notificationOccurred(.warning)
#endif
            }
        }
    }

    private func didTapOnButton() {
        if isEnabled {
            justAdded.toggle()

            score.append(Score(time: .now))
            increased += 1

            self.lastTapped = name
            saveAndSync()
        }
    }

    private func saveAndSync() {
        do {
            try modelContext.save()
            // Delay slightly to ensure save completes before sync
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onScoreChanged?()
            }
        } catch {
            print("📱 TapButton: Failed to save: \(error)")
        }
    }
}

#Preview("Tap button") {
    TapButton(
        score: .constant([Date()].map { Score(time: $0) }),
        colorHex: .constant(Color.primary.toHex()),
        name: .constant("Team Name"),
        lastTapped: .constant("")
    )
    .background(.gray)
}

