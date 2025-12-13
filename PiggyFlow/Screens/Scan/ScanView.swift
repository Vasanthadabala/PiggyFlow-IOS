//
//  ScanView.swift
//  PiggyFlow
//
//  Created by Vasanth on 27/10/25.
//

import SwiftUI
import SwiftData
import VisionKit
import Vision

struct ScanView: View {
    @Environment(\.modelContext) private var context
    @State private var showingScanner = false
    @State private var scanResults: [String] = []
    @State private var isProcessing = false
    @State private var alertMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("Beta Version")
                .font(.system(size: 16, weight: .regular, design: .serif))
                .foregroundColor(.gray)
            
            Image(systemName: "doc.text.viewfinder")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.green)

            Text("Scan your bill to auto-add expenses")
                .font(.system(size: 18, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingScanner = true
            } label: {
                Text("Start Scanning")
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 18, weight: .medium, design: .serif))
            }
            .padding(.vertical, 10)
            .padding(.horizontal)
            .foregroundColor(.white)
            .background(Color.green.gradient)
            .cornerRadius(12)
            .padding()

            if isProcessing {
                ProgressView("Processing Bill…")
                    .padding()
            }

            if !scanResults.isEmpty {
                List(scanResults, id: \.self) { line in
                    Text(line)
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            ScannerView { images in
                Task {
                    await handleScannedImages(images)
                }
            }
        }
        .alert(isPresented: .constant(alertMessage != nil)) {
            Alert(
                title: Text("Done"),
                message: Text(alertMessage ?? ""),
                dismissButton: .default(Text("OK"), action: {
                    alertMessage = nil
                })
            )
        }
    }

    // MARK: - Handle Scanned Images
    func handleScannedImages(_ images: [UIImage]) async {
        isProcessing = true
        var allText = ""
        for image in images {
            if let text = try? await extractText(from: image) {
                allText += text + "\n"
            }
        }
        
        let parsedItems = parseBillText(allText)
        scanResults = parsedItems.map { "\($0.item): ₹\($0.price)" }

        // Save parsed items to SwiftData
        for parsed in parsedItems {
            let newExpense = Expense(
                type:"Expense",
                emoji: "🧾",
                name: parsed.item,
                price: parsed.price,
                date: Date(),
                note: "Scanned from bill"
            )
            context.insert(newExpense)
        }

        try? context.save()
        isProcessing = false
        alertMessage = "Added \(parsedItems.count) expenses from your bill!"
    }
}

// MARK: - Scanner
struct ScannerView: UIViewControllerRepresentable {
    var onScanComplete: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanComplete: onScanComplete)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onScanComplete: ([UIImage]) -> Void
        
        init(onScanComplete: @escaping ([UIImage]) -> Void) {
            self.onScanComplete = onScanComplete
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true)
            onScanComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            print("Scan failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - OCR and Parsing
func extractText(from image: UIImage) async throws -> String {
    guard let cgImage = image.cgImage else { return "" }
    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    
    try requestHandler.perform([request])
    
    let recognizedText = request.results?
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n") ?? ""
    
    return recognizedText
}

func parseBillText(_ text: String) -> [(item: String, price: Double)] {
    var results: [(String, Double)] = []
    let lines = text.components(separatedBy: "\n")
    
    for line in lines {
        // Match pattern like "Apple 45.00" or "Bread - 30.5"
        if let match = line.range(of: #"([A-Za-z\s]+)\s+(\d+(\.\d{1,2})?)"#, options: .regularExpression) {
            let itemLine = String(line[match])
            let parts = itemLine.split(separator: " ")
            if let last = parts.last, let amount = Double(last) {
                let name = parts.dropLast().joined(separator: " ")
                results.append((name, amount))
            }
        }
    }
    return results
}

#Preview {
    ScanView()
}
