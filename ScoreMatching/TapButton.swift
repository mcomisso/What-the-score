import Foundation
import WhatScoreKit
import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mcomisso.ScoreMatching", category: "TapButton")

struct TapButton: View {
    @ScaledMetric(relativeTo: .largeTitle) private var scoreScale: CGFloat = 1

    @AppStorage(AppStorageValues.shouldAllowNegativePoints)
    var shouldAllowNegativePoints: Bool = false
    @Environment(\.modelContext) var modelContext

    @Binding var score: [Score]
    @Binding var colorHex: String
    @Binding var name: String
    @Binding var lastTapped: String?

    var isEnabled: Bool = true
    var scoreValues: [Int] = [1]
    var onScoreChanged: (() -> Void)?
    #if os(iOS)
    private let warningGenerator = UINotificationFeedbackGenerator()
    #endif

    @State private var increased: Int = 0
    @State private var decreased: Int = 0

    @State private var showAddition = false
    @State private var latestAddition = 1
    @State private var additionID = UUID()
    @State private var additionTask: Task<Void, Never>?
    @State private var tapLocation: CGPoint?
    @State private var additionLocation: CGPoint = .zero
    @State private var additionAngle: Double = 0

    var body: some View {
        GeometryReader { geometryProxy in
            Button {
                let location = tapLocation ?? CGPoint(
                    x: geometryProxy.size.width / 2,
                    y: geometryProxy.size.height / 2
                )
                tapLocation = nil
                addScore(primaryScoreValue, at: location)
            } label: {
                VStack(spacing: 0) {
                    let contentHeight = max(1, geometryProxy.size.height)
                    let fontSize = min(
                        min(geometryProxy.size.width, contentHeight) / 3.5 * scoreScale,
                        contentHeight * 0.55
                    )
                    let displayScore = shouldAllowNegativePoints ? score.totalScore : score.safeTotalScore
                    Text("\(displayScore)")
                        .font(.system(size: fontSize, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.25)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: displayScore)
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity)
                    Text(name)
                        .bold()
                        .font(.system(.headline, design: .default))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    if scoreValues.count > 1 {
                        Text("Hold for other values")
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.bottom, 8)
                    } else if primaryScoreValue != 1 {
                        Text("Tap adds \(primaryScoreValue)")
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.bottom, 8)
                    }
                }
                .foregroundStyle(Color(hex: colorHex))
                .colorInvert()
                .frame(maxWidth: .infinity,
                       maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(name), score \(shouldAllowNegativePoints ? score.totalScore : score.safeTotalScore)")
            .accessibilityHint("Activate to add \(primaryScoreValue), or use Remove Point")
            .accessibilityAction(named: Text("Remove Point")) {
                removePoint()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { tapLocation = $0.startLocation }
                    .onEnded(onGestureEnd)
            )
            .contextMenu {
                ForEach(scoreValues, id: \.self) { value in
                    Button("Add \(value)") {
                        addScore(
                            value,
                            at: CGPoint(
                                x: geometryProxy.size.width / 2,
                                y: geometryProxy.size.height / 2
                            )
                        )
                    }
                }
            }
            #if os(iOS)
            .sensoryFeedback(.increase, trigger: increased)
            .sensoryFeedback(.decrease, trigger: decreased)
            #endif
            .overlay {
                if showAddition {
                    Text("+\(latestAddition)")
                        .foregroundStyle(Color(hex: colorHex))
                        .scaleEffect(x: 2, y: 2, anchor: .center)
                        .rotationEffect(.degrees(additionAngle))
                        .colorInvert()
                        .position(additionLocation)
                        .id(additionID)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var primaryScoreValue: Int { scoreValues.first ?? 1 }

    private func onGestureEnd(_ value: DragGesture.Value) {
        let translation = value.translation
        if abs(translation.width) > 12 || abs(translation.height) > 12 {
            tapLocation = nil
        }
        guard abs(translation.width) >= 40,
              abs(translation.width) > abs(translation.height) * 1.25 else {
            return
        }
        removePoint()
    }

    private func removePoint() {
        if score.subtractPoint(allowNegativePoints: shouldAllowNegativePoints) {
            decreased += 1
            saveAndSync()
        } else {
#if os(iOS)
            warningGenerator.notificationOccurred(.warning)
#endif
        }
    }

    private func addScore(_ value: Int, at location: CGPoint) {
        if isEnabled {
            additionTask?.cancel()
            additionID = UUID()
            additionLocation = location
            additionAngle = Double.random(in: -12...12)
            withAnimation(.easeOut(duration: 0.2)) {
                showAddition = true
            }
            additionTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    showAddition = false
                }
            }

            latestAddition = value
            score.addPoint(value: value)
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
            logger.error("Failed to save: \(error.localizedDescription)")
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
