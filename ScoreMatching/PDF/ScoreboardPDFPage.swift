import Foundation
import PDFKit
import SwiftUI
import UIKit

class ScoreboardPage: PDFPage {

    var teams: [Team] = []
    var intervals: [Interval] = []
    var generatedDate: Date = Date()

    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        super.draw(with: box, to: context)

        UIGraphicsPushContext(context)
        context.saveGState()

        let pageBounds = self.bounds(for: box)
        context.translateBy(x: 0.0, y: pageBounds.size.height)
        context.scaleBy(x: 1.0, y: -1.0)

        drawScoreboard(in: pageBounds)

        context.restoreGState()
        UIGraphicsPopContext()
    }

    private func drawScoreboard(in bounds: CGRect) {
        let margin: CGFloat = 40
        var yPosition: CGFloat = margin

        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        let title = "Scoreboard Report"
        (title as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
        yPosition += 40

        // Date
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateString = "Generated: \(dateFormatter.string(from: generatedDate))"
        (dateString as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
        yPosition += 40

        // Final Scores Section
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        ("Final Scores" as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
        yPosition += 30

        // Draw teams and scores
        let teamAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        let scoreAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]

        for team in teams {
            // Draw color indicator
            let colorRect = CGRect(x: margin, y: yPosition, width: 20, height: 20)
            let color = UIColor(Color(hex: team.color))
            color.setFill()
            UIBezierPath(roundedRect: colorRect, cornerRadius: 4).fill()

            // Draw team name
            (team.name as NSString).draw(at: CGPoint(x: margin + 30, y: yPosition), withAttributes: teamAttributes)

            // Draw score
            let scoreText = "\(team.score.totalScore)"
            let scoreX = bounds.width - margin - 100
            (scoreText as NSString).draw(at: CGPoint(x: scoreX, y: yPosition), withAttributes: scoreAttributes)

            yPosition += 30
        }

        // Intervals Section
        if !intervals.isEmpty {
            yPosition += 20
            ("Interval Breakdown" as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionAttributes)
            yPosition += 30

            let intervalHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            let intervalDataAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]

            for (index, interval) in intervals.enumerated() {
                // Interval name
                (interval.name as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: intervalHeaderAttributes)
                yPosition += 20

                // Team scores in this interval
                let previousInterval = index > 0 ? intervals[index - 1] : nil
                let scoreGained = interval.scoreGained(previousInterval: previousInterval)

                for snapshot in interval.teamSnapshots {
                    let teamColor = UIColor(Color(hex: snapshot.teamColor))
                    let colorRect = CGRect(x: margin + 20, y: yPosition, width: 12, height: 12)
                    teamColor.setFill()
                    UIBezierPath(roundedRect: colorRect, cornerRadius: 2).fill()

                    let teamText = snapshot.teamName
                    (teamText as NSString).draw(at: CGPoint(x: margin + 40, y: yPosition - 2), withAttributes: intervalDataAttributes)

                    let scoreText = "\(snapshot.totalScore)"
                    let scoreX = bounds.width - margin - 120
                    (scoreText as NSString).draw(at: CGPoint(x: scoreX, y: yPosition - 2), withAttributes: intervalDataAttributes)

                    if let gained = scoreGained[snapshot.teamName] {
                        let gainedText = "(+\(gained))"
                        let gainedX = bounds.width - margin - 60
                        let gainedAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 10),
                            .foregroundColor: UIColor.systemGreen
                        ]
                        (gainedText as NSString).draw(at: CGPoint(x: gainedX, y: yPosition - 2), withAttributes: gainedAttributes)
                    }

                    yPosition += 18
                }

                yPosition += 10
            }
        }

        // Footer
        yPosition = bounds.height - margin - 20
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 10),
            .foregroundColor: UIColor.lightGray
        ]
        let footer = "Generated by What the Score"
        (footer as NSString).draw(at: CGPoint(x: margin, y: yPosition), withAttributes: footerAttributes)
    }
}
