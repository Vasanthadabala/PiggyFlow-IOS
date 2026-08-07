import AVFoundation
import UIKit
import Combine

/// Owns the `AVCaptureSession` behind the bill-scanning viewfinder.
///
/// Session setup and photo capture are kept out of the view so the screen stays declarative,
/// and so the "no camera available" path (Simulator, denied permission) is a published state
/// the UI can render rather than a crash.
@MainActor
final class CameraService: NSObject, ObservableObject {

    enum Status: Equatable {
        case idle
        case running
        /// No usable capture device — the Simulator, or a device with no back camera.
        case unavailable
        case denied
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var isFlashOn = false
    /// True while a capture is in flight, so the shutter can't be double-fired.
    @Published private(set) var isCapturing = false

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private var deviceInput: AVCaptureDeviceInput?
    /// Configuration and start/stop must stay off the main thread — `startRunning()` blocks.
    private let sessionQueue = DispatchQueue(label: "com.piggyflow.camera.session")
    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    // MARK: - Lifecycle

    /// Requests access if needed, configures the session, and starts it.
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else {
                status = .denied
                return
            }
        case .denied, .restricted:
            status = .denied
            return
        @unknown default:
            status = .denied
            return
        }

        guard configureIfNeeded() else { return }

        sessionQueue.async { [session] in
            guard !session.isRunning else { return }
            session.startRunning()
        }
        status = .running
    }

    func stop() {
        sessionQueue.async { [session] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
        if status == .running { status = .idle }
    }

    // MARK: - Configuration

    /// Returns false (and sets `status`) when there's nothing to capture with.
    private func configureIfNeeded() -> Bool {
        guard !isConfigured else { return true }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            // Expected on Simulator — surface it instead of failing silently.
            status = .unavailable
            return false
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            status = .failed("Couldn't set up the camera.")
            return false
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        session.commitConfiguration()

        deviceInput = input
        isConfigured = true
        return true
    }

    // MARK: - Torch

    /// Toggles the torch. No-op when the device has none.
    func toggleFlash() {
        guard let device = deviceInput?.device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = device.torchMode == .on ? .off : .on
            isFlashOn = device.torchMode == .on
            device.unlockForConfiguration()
        } catch {
            Log.error(error, context: "Toggling torch", category: .general)
        }
    }

    // MARK: - Capture

    /// Captures a still, returning `nil` if the shot failed.
    func capturePhoto() async -> UIImage? {
        guard status == .running, !isCapturing else { return nil }
        isCapturing = true
        defer { isCapturing = false }

        let settings = AVCapturePhotoSettings()
        if deviceInput?.device.hasFlash == true {
            settings.flashMode = isFlashOn ? .on : .off
        }

        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage? = {
            if let error {
                Log.error(error, context: "Capturing photo", category: .general)
                return nil
            }
            guard let data = photo.fileDataRepresentation() else { return nil }
            return UIImage(data: data)
        }()

        Task { @MainActor in
            captureContinuation?.resume(returning: image)
            captureContinuation = nil
        }
    }
}
