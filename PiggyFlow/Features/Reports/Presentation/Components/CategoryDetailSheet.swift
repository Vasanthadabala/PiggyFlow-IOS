//
//  CategoryDetailSheet.swift
//  PiggyFlow
//
//  Created by Vasanth on 12/12/25.
//

import SwiftUI
import SwiftData
import PDFKit

struct CategoryDetailSheet: View {
    @Environment(\.dismiss) var categoryDetailBottomSheetDismiss
    
    let categoryName: String
    let selectedFlow: StatsFlow
    let expenses: [Expense]
    let incomes: [Income]
    
    // Filter items for this category
    private var categoryExpenses: [Expense] {
        expenses.filter { $0.name == categoryName }
    }
    
    private var categoryIncomes: [Income] {
        incomes.filter { $0.name == categoryName }
    }
    
    // Total income
    private var totalIncome: Double {
        selectedFlow == .income ? categoryIncomes.reduce(0) { $0 + $1.income } : 0
    }

    // Total expenses (optional, if you want to show spent)
    private var totalExpenses: Double {
        selectedFlow == .expense ? categoryExpenses.reduce(0) { $0 + $1.price } : 0
    }
    
    private var themeColor: Color {
        selectedFlow == .expense ? .appExpenseRed : .appGreen
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                // Close button pinned at top right
                HStack {
                    Spacer()
                    Button {
                        categoryDetailBottomSheetDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 26, height: 26)
                            .foregroundStyle(.white, .red)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Summary hero
                VStack(spacing: 8) {
                    Text(categoryName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("TOTAL \(selectedFlow == .expense ? "SPENT" : "EARNED")")
                        .sectionEyebrow(color: .white.opacity(0.72))

                    Text("₹\(selectedFlow == .expense ? totalExpenses : totalIncome, specifier: "%.2f")")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .gradientHero(selectedFlow == .expense ? [.appExpenseRed, .appExpenseRedDeep] : [.appGreen, .appGreenDeep])

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        if (selectedFlow == .expense ? categoryExpenses.isEmpty : categoryIncomes.isEmpty) {
                            Text("No transactions found.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        }

                        // EXPENSES
                        if selectedFlow == .expense && !categoryExpenses.isEmpty {
                            ForEach(Array(categoryExpenses.enumerated()), id: \.element.id) { pair in
                                let exp = pair.element
                                let formattedDate = exp.date.formattedCompact

                                HStack(spacing: 12) {
                                    TintedIconCircle(color: .appExpenseRed, size: 40, cornerRadius: 13) {
                                        Text(exp.emoji.isEmpty ? exp.name.prefix(1).uppercased() : exp.emoji)
                                            .font(.system(size: 18))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exp.note.isEmpty ? exp.name : exp.note)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        Text(formattedDate)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("-₹\(exp.price, specifier: "%.2f")")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.appExpenseRed)
                                }
                                .flatRow(vertical: 10, horizontal: 0)

                                if pair.offset != categoryExpenses.count - 1 {
                                    RowDivider()
                                }
                            }
                        }

                        // INCOMES
                        if selectedFlow == .income && !categoryIncomes.isEmpty {
                            ForEach(Array(categoryIncomes.enumerated()), id: \.element.id) { pair in
                                let inc = pair.element
                                let formattedDate = inc.date.formattedCompact

                                HStack(spacing: 12) {
                                    TintedIconCircle(color: .appGreen, size: 40, cornerRadius: 13) {
                                        Text(inc.emoji.isEmpty ? inc.name.prefix(1).uppercased() : inc.emoji)
                                            .font(.system(size: 18))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(inc.note.isEmpty ? inc.name : inc.note)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        Text(formattedDate)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("+₹\(inc.income, specifier: "%.2f")")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.appGreen)
                                }
                                .flatRow(vertical: 10, horizontal: 0)

                                if pair.offset != categoryIncomes.count - 1 {
                                    RowDivider()
                                }
                            }
                        }
                    }
                    .padding(16)
                    .groupedCard()
                }

                Button {
                    Haptics.light()
                    exportPDF()
                } label: {
                    Text("Export PDF")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.appGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }
    
    // MARK: - PDF Export
    func exportPDF() {
        let pdfMetaData = [
            kCGPDFContextCreator: "PiggyFlow",
            kCGPDFContextAuthor: "Vasanth",
            kCGPDFContextTitle: "\(categoryName) Report"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth: CGFloat = 8.5 * 72
        let pageHeight: CGFloat = 11 * 72
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let pdfData = renderer.pdfData { context in
            context.beginPage()
            
            var y: CGFloat = 40

            // Title
            let title = "\(categoryName) Report"
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            title.draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: titleFont])
            y += 40

            // Summary Section
            y = drawSectionHeader("Summary", y: y)

            let summaryText = """
            Total Income: ₹\(totalIncome.formatted())
            Total Expense: ₹\(totalExpenses.formatted())
            Available: ₹\((totalIncome - totalExpenses).formatted())
            """

            y = drawMultilineText(summaryText, x: 40, y: y + 10)

            // Expenses Section
//            if !categoryExpenses.isEmpty {
//                y += 20
//                y = drawSectionHeader("Expenses", y: y)
//
//                for exp in categoryExpenses {
//                    let dateFormatted = DateFormatter.localizedString(from: exp.date, dateStyle: .medium, timeStyle: .none)
//                    let line = "\(exp.emoji)  \(exp.note.isEmpty ? exp.name : exp.note) - ₹\(exp.price)   (\(dateFormatted))"
//                    y = drawMultilineText(line, x: 40, y: y + 6)
//
//                    if y > pageHeight - 80 {
//                        context.beginPage()
//                        y = 40
//                    }
//                }
//            }
            if !categoryExpenses.isEmpty {
                y += 20
                y = drawSectionHeader("Expenses", y: y)
                y = PDFTableRenderer.drawHeader(y: y)

                for exp in categoryExpenses {
                    let dateFormatted = DateFormatter.localizedString(from: exp.date, dateStyle: .medium, timeStyle: .none)
                    let name = "\(exp.emoji) \(exp.note.isEmpty ? exp.name : exp.note)"
                    let amount = "-₹\(exp.price.formatted())"
                    
                    y = PDFTableRenderer.drawRow(name: name, amount: amount, date: dateFormatted, y: y)

                    if y > pageHeight - 80 {
                        context.beginPage()
                        y = 40
                        y = PDFTableRenderer.drawHeader(y: y)
                    }
                }
            }


            // Incomes Section
//            if !categoryIncomes.isEmpty {
//                y += 20
//                y = drawSectionHeader("Incomes", y: y)
//
//                for inc in categoryIncomes {
//                    let dateFormatted = DateFormatter.localizedString(from: inc.date, dateStyle: .medium, timeStyle: .none)
//                    let line = "\(inc.emoji)  \(inc.note.isEmpty ? inc.name : inc.note) - ₹\(inc.income)   (\(dateFormatted))"
//                    y = drawMultilineText(line, x: 40, y: y + 6)
//
//                    if y > pageHeight - 80 {
//                        context.beginPage()
//                        y = 40
//                    }
//                }
//            }
            
            if !categoryIncomes.isEmpty {
                y += 20
                y = drawSectionHeader("Incomes", y: y)
                y = PDFTableRenderer.drawHeader(y: y)

                for inc in categoryIncomes {
                    let dateFormatted = DateFormatter.localizedString(from: inc.date, dateStyle: .medium, timeStyle: .none)
                    let name = "\(inc.emoji) \(inc.note.isEmpty ? inc.name : inc.note)"
                    let amount = "+₹\(inc.income.formatted())"
                    
                    y = PDFTableRenderer.drawRow(name: name, amount: amount, date: dateFormatted, y: y)

                    if y > pageHeight - 80 {
                        context.beginPage()
                        y = 40
                        y = PDFTableRenderer.drawHeader(y: y)
                    }
                }
            }

        }

        saveAndSharePDF(data: pdfData)
    }
    
    // Draw section title
    func drawSectionHeader(_ text: String, y: CGFloat) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 20)
        text.draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: font])
        return y + 30
    }

    // Draw multi-line text
    func drawMultilineText(_ text: String, x: CGFloat, y: CGFloat) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .paragraphStyle: paragraph
        ]

        let maxWidth: CGFloat = 500
        let height = text.height(withConstrainedWidth: maxWidth, attributes: attributes)

        text.draw(
            in: CGRect(x: x, y: y, width: maxWidth, height: height),
            withAttributes: attributes
        )

        return y + height
    }
    

    // Save & share PDF
    func saveAndSharePDF(data: Data) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(categoryName).pdf")
        
        do {
            try data.write(to: url)
            
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            // IMPORTANT: Present from top-most controller, not from sheet's root view
            if let topVC = UIApplication.topViewController() {
                DispatchQueue.main.async {
                    topVC.present(av, animated: true)
                }
            } else {
                print("❌ No top view controller found")
            }
            
        } catch {
            print("❌ Error saving PDF:", error)
        }
    }
}
