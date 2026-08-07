import SwiftUI
import VisionKit

/// Wraps `VNDocumentCameraViewController` for multi-page capture.
///
/// VisionKit handles edge detection, perspective correction and multi-page batching — all
/// of which matter for long receipts, and none of which are worth reimplementing on top of
/// the custom single-shot viewfinder.
struct DocumentScannerView: UIViewControllerRepresentable {

    var onComplete: ([UIImage]) -> Void
    var onCancel: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {

        private let onComplete: ([UIImage]) -> Void
        private let onCancel: () -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            controller.dismiss(animated: true)
            onComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            Log.error(error, context: "Document scanner", category: .general)
            controller.dismiss(animated: true)
            onCancel()
        }
    }
}
