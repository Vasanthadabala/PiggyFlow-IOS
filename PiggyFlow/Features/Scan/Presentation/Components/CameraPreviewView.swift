import SwiftUI
import AVFoundation

/// Hosts the `AVCaptureVideoPreviewLayer` for a capture session.
///
/// A `UIViewRepresentable` is required because the preview is a `CALayer`, which SwiftUI
/// can't render directly. Resizing is handled by the backing view rather than by SwiftUI
/// layout so the layer tracks bounds changes (rotation, sheet resize) without stretching.
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }

    /// Backing view whose layer *is* the preview layer, so bounds stay in sync for free.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // Safe: `layerClass` guarantees the type.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

/// The four L-shaped corner marks that frame the bill.
struct ViewfinderFrame: View {

    var cornerLength: CGFloat = 34
    var lineWidth: CGFloat = 4
    var inset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - inset * 2
            let h = geo.size.height - inset * 2

            Path { path in
                // Top-left
                path.move(to: CGPoint(x: 0, y: cornerLength))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: cornerLength, y: 0))
                // Top-right
                path.move(to: CGPoint(x: w - cornerLength, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: cornerLength))
                // Bottom-right
                path.move(to: CGPoint(x: w, y: h - cornerLength))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w - cornerLength, y: h))
                // Bottom-left
                path.move(to: CGPoint(x: cornerLength, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: h - cornerLength))
            }
            .stroke(
                Color.white,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .offset(x: inset, y: inset)
        }
    }
}
