import SwiftUI
import ScoreMatchingKit

struct TeamButtonView: View {
    @Binding var team: Team
    @AppStorage("shouldAllowNegativePoints") var shouldAllowNegativePoints: Bool = false

    var onScoreChanged: (() -> Void)?

    @State private var increased: Int = 0
    @State private var decreased: Int = 0
    @State private var justAdded: Bool = false

    var body: some View {
        let displayScore = shouldAllowNegativePoints ? team.score.totalScore : team.score.safeTotalScore
        let backgroundColor = Color(hex: team.color)
        let textColor = contrastingColor(for: backgroundColor)

        Button {
            incrementScore()
        } label: {
            VStack(spacing: 4) {
                Text("\(displayScore)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text(team.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(hex: team.color))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { _ in
                    decrementScore()
                }
        )
        .sensoryFeedback(.increase, trigger: increased)
        .sensoryFeedback(.decrease, trigger: decreased)
    }

    private func incrementScore() {
        justAdded.toggle()
        team.score.append(Score(time: .now, value: 1))
        increased += 1
        onScoreChanged?()
    }

    private func decrementScore() {
        if shouldAllowNegativePoints {
            team.score.append(Score(time: .now, value: -1))
            decreased += 1
            onScoreChanged?()
        } else {
            if !team.score.isEmpty {
                team.score.removeLast()
                decreased += 1
                onScoreChanged?()
            }
        }
    }

    private func contrastingColor(for backgroundColor: Color) -> Color {
        // For simplicity, use white for dark colors and black for light colors
        // This is a heuristic that works well for most cases
        return .white
    }
}

