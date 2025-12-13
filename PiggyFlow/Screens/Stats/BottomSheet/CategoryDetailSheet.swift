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
        categoryIncomes.reduce(0) { $0 + $1.income }
    }

    // Total expenses (optional, if you want to show spent)
    private var totalExpenses: Double {
        categoryExpenses.reduce(0) { $0 + $1.price }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            
            // Close button pinned at top right
            HStack {
                Spacer()
                Button(action: { categoryDetailBottomSheetDismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(Color.red)
                        .padding(.vertical)
                }
            }
            
            Text(categoryName)
                .font(.system(size: 24, weight: .bold, design: .serif))
            
            Divider()
            
            HStack{
                HStack {
                    Text("Amount")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundColor(Color.gray)
                    
                    Spacer()
                        .frame(width: 4)
                    
                    Text("\(totalIncome, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                }
                
                Spacer()
                
                HStack {
                    Text("Available")
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundColor(Color.gray)
                    
                    Spacer()
                        .frame(width: 4)
                    
                    Text("\(totalIncome - totalExpenses, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .medium, design: .serif))
                }
            }
            
            Spacer()
                .frame(height: 8)
            
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    
                    if categoryExpenses.isEmpty && categoryIncomes.isEmpty {
                        Text("No transactions found.")
                            .foregroundColor(.gray)
                    }
                    
                    // EXPENSES
                    if !categoryExpenses.isEmpty {
                        Text("Expenses")
                            .font(.headline)
                        
                        ForEach(categoryExpenses) { exp in
                            
                            var formattedDate: String {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "MMM dd"
                                return formatter.string(from: exp.date)
                            }
                            
                            HStack{
                                HStack {
                                    
                                    Text(exp.emoji.isEmpty ? exp.name.prefix(1).uppercased() : exp.emoji)
                                        .font(.system(size: 24))
                                        .frame(width: 40, height: 40)
                                        .background(Color.red.opacity(0.2))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading) {
                                        Text(exp.note.isEmpty ? exp.name : exp.note)
                                        Text(formattedDate)
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Text("-₹\(exp.price, specifier: "%.2f")")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.1))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                        )
                    }
                    
                    // INCOMES
                    if !categoryIncomes.isEmpty {
                        Text("Incomes")
                            .font(.headline)
                            .padding(.top)
                        
                        ForEach(categoryIncomes) { inc in
                            
                            var formattedDate: String {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "MMM dd"
                                return formatter.string(from: inc.date)
                            }
                            HStack {
                                HStack {
                                    
                                    Text(inc.emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 40, height: 40)
                                        .background(Color.green.opacity(0.2))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading) {
                                        Text(inc.note.isEmpty ? inc.name : inc.note)
                                        Text(formattedDate)
                                            .foregroundColor(.gray)
                                            .font(.caption)
                                    }
                                    Spacer()
                                    Text("+₹\(inc.income, specifier: "%.2f")")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.1))
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                            )
                        }
                    }
                }
            }
            
            Spacer()
            
            Button{
                exportPDF()
            } label: {
                Text("Export Pdf")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.system(size: 18, weight: .medium, design: .serif))
            }
            .padding(.vertical, 10)
            .padding(.horizontal)
            .foregroundColor(.white)
            .background(Color.green.gradient)
            .cornerRadius(12)

        }
        .padding()
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
                y = drawTableHeader(y)

                for exp in categoryExpenses {
                    let dateFormatted = DateFormatter.localizedString(from: exp.date, dateStyle: .medium, timeStyle: .none)
                    let name = "\(exp.emoji) \(exp.note.isEmpty ? exp.name : exp.note)"
                    let amount = "-₹\(exp.price.formatted())"
                    
                    y = drawTableRow(name: name, amount: amount, date: dateFormatted, y: y)

                    if y > pageHeight - 80 {
                        context.beginPage()
                        y = 40
                        y = drawTableHeader(y)
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
                y = drawTableHeader(y)

                for inc in categoryIncomes {
                    let dateFormatted = DateFormatter.localizedString(from: inc.date, dateStyle: .medium, timeStyle: .none)
                    let name = "\(inc.emoji) \(inc.note.isEmpty ? inc.name : inc.note)"
                    let amount = "+₹\(inc.income.formatted())"
                    
                    y = drawTableRow(name: name, amount: amount, date: dateFormatted, y: y)

                    if y > pageHeight - 80 {
                        context.beginPage()
                        y = 40
                        y = drawTableHeader(y)
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
    
    func drawTableHeader(_ y: CGFloat) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 17)
        
        "Name".draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: headerFont])
        "Amount".draw(at: CGPoint(x: 300, y: y), withAttributes: [.font: headerFont])
        "Date".draw(at: CGPoint(x: 420, y: y), withAttributes: [.font: headerFont])
        
        return y + 28
    }

    // Save & share PDF
    func saveAndSharePDF(data: Data) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(categoryName).pdf")
        
        do {
            try data.write(to: url)
            
            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            // IMPORTANT: Present from top-most controller, not from sheet's root view
            if let topVC = topMostViewController() {
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

extension String {
    func height(withConstrainedWidth width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        return ceil(boundingBox.height)
    }
    
}

func topMostViewController(_ root: UIViewController? = nil) -> UIViewController? {
    let rootVC = root ?? UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController

    if let nav = rootVC as? UINavigationController {
        return topMostViewController(nav.visibleViewController)
    }
    if let tab = rootVC as? UITabBarController {
        return topMostViewController(tab.selectedViewController)
    }
    if let presented = rootVC?.presentedViewController {
        return topMostViewController(presented)
    }

    return rootVC
}

@discardableResult
func drawTableRow(name: String, amount: String, date: String, y: CGFloat) -> CGFloat {
    let nameFont = UIFont.systemFont(ofSize: 16)
    let amountFont = UIFont.systemFont(ofSize: 16)
    let dateFont = UIFont.systemFont(ofSize: 16)
    
    let nameX: CGFloat = 40
    let amountX: CGFloat = 300
    let dateX: CGFloat = 420
    
    let rowHeight: CGFloat = 22
    
    name.draw(at: CGPoint(x: nameX, y: y), withAttributes: [.font: nameFont])
    amount.draw(at: CGPoint(x: amountX, y: y), withAttributes: [.font: amountFont])
    date.draw(at: CGPoint(x: dateX, y: y), withAttributes: [.font: dateFont])
    
    return y + rowHeight
}


