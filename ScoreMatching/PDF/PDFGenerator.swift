import Foundation
import PDFKit

class PDFCreator: NSObject, PDFDocumentDelegate {
    var pdfDocument: PDFDocument = .init()

    override init() {
        super.init()
        pdfDocument.delegate = self
    }

    func classForPage() -> AnyClass {
        ScoreboardPage.self
    }
}
