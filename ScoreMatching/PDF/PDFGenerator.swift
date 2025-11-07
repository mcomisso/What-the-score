import Foundation
import WhatScoreKit
import PDFKit
import UIKit

class PDFCreator: NSObject, PDFDocumentDelegate {
    var pdfDocument: PDFDocument = .init()

    override init() {
        super.init()
        pdfDocument.delegate = self
    }

    func classForPage() -> AnyClass {
        ScoreboardPage.self
    }

    static func generateScoreboardPDF(teams: [Team], intervals: [Interval]) -> PDFDocument? {
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size

        let page = ScoreboardPage()
        page.teams = teams
        page.intervals = intervals
        page.generatedDate = Date()
        page.setBounds(pageSize, for: .mediaBox)

        let document = PDFDocument()
        document.insert(page, at: 0)

        return document
    }

    static func savePDFToTemporaryFile(document: PDFDocument) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Scoreboard_\(Date().timeIntervalSince1970).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)

        if document.write(to: fileURL) {
            return fileURL
        }

        return nil
    }
}
