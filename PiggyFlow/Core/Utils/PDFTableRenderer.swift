import UIKit

/// Column layout for the transaction tables drawn into exported PDFs.
enum PDFTableRenderer {
    private static let nameX: CGFloat = 40
    private static let amountX: CGFloat = 300
    private static let dateX: CGFloat = 420
    private static let rowHeight: CGFloat = 22

    /// Draws one table row at vertical offset `y`, returning the offset for the next row.
    @discardableResult
    static func drawRow(name: String, amount: String, date: String, y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 16)

        name.draw(at: CGPoint(x: nameX, y: y), withAttributes: [.font: font])
        amount.draw(at: CGPoint(x: amountX, y: y), withAttributes: [.font: font])
        date.draw(at: CGPoint(x: dateX, y: y), withAttributes: [.font: font])

        return y + rowHeight
    }

    /// Draws the bold column headings, returning the offset for the first data row.
    @discardableResult
    static func drawHeader(y: CGFloat) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 17)

        "Name".draw(at: CGPoint(x: nameX, y: y), withAttributes: [.font: headerFont])
        "Amount".draw(at: CGPoint(x: amountX, y: y), withAttributes: [.font: headerFont])
        "Date".draw(at: CGPoint(x: dateX, y: y), withAttributes: [.font: headerFont])

        return y + 28
    }
}
