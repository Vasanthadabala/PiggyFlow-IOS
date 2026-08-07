import Foundation
import UIKit
import Vision

/// A line item read off a receipt, before the user has reviewed it.
struct ParsedItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var price: String
}

/// Runs OCR over captured receipt images and turns the text into editable line items.
///
/// Extraction is best-effort — receipts vary wildly — so the output is always presented for
/// review rather than saved directly.
struct ExtractBillItemsUseCase {

    /// Recognises text in each image and parses line items from the combined result.
    func execute(images: [UIImage]) async -> [ParsedItem] {
        var combinedText = ""
        for image in images {
            if let text = try? await recognizeText(in: image) {
                combinedText += text + "\n"
            }
        }
        return parse(combinedText)
    }

    // MARK: - OCR

    /// Vision's text recognition is synchronous and CPU-heavy, so it runs off the main actor.
    private func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                    let text = request.results?
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n") ?? ""
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Parsing

    /// Lines that are receipt furniture rather than purchases.
    private static let noiseKeywords = [
        "subtotal", "total", "discount", "cgst", "sgst", "igst", "gst", "tax",
        "cash", "change", "balance", "paid", "upi", "card", "invoice", "bill no",
        "phone", "gstin", "cashier", "date", "thank", "visit", "qty", "amount"
    ]

    /// Pulls `name … price` pairs out of raw OCR text.
    ///
    /// Matches the *trailing* number on each line, which on a typical receipt is the line
    /// amount — quantity and unit price sit between the name and it.
    func parse(_ text: String) -> [ParsedItem] {
        text
            .components(separatedBy: .newlines)
            .compactMap { lineItem(from: $0) }
    }

    private func lineItem(from rawLine: String) -> ParsedItem? {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return nil }

        let lowercased = line.lowercased()
        guard !Self.noiseKeywords.contains(where: { lowercased.contains($0) }) else { return nil }

        // Last number on the line, allowing thousands separators and an optional ₹.
        let numberPattern = #"[₹]?\s*\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?$"#
        guard let priceRange = line.range(of: numberPattern, options: .regularExpression) else {
            return nil
        }

        let priceText = line[priceRange]
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let amount = Double(priceText), amount > 0 else { return nil }

        // Everything before the price, minus any trailing qty/unit-price columns.
        var name = String(line[line.startIndex..<priceRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        name = name.replacingOccurrences(
            of: #"\s+[₹]?\d+(\.\d{1,2})?$"#,
            with: "",
            options: .regularExpression
        )
        name = name.replacingOccurrences(
            of: #"\s+[₹]?\d+(\.\d{1,2})?$"#,
            with: "",
            options: .regularExpression
        )
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " .:-–—"))

        // Require at least a couple of letters so stray numeric rows don't become items.
        guard name.count >= 2,
              name.rangeOfCharacter(from: .letters) != nil else { return nil }

        return ParsedItem(name: name, price: String(format: "%.2f", amount))
    }
}
