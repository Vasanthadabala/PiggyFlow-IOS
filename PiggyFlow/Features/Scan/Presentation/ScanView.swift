import SwiftUI
import SwiftData
import PhotosUI

/// Bill-scanning viewfinder.
///
/// A live camera preview fills the middle of the screen with capture controls overlaid, and
/// a card below explains what the scan will extract. Three ways in: shutter (single shot),
/// Upload Bill (photo library), or Enter Manually (skip scanning entirely).
struct ScanView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @StateObject private var camera = CameraService()

    /// Single = one shot from the custom viewfinder; Multi = VisionKit's batch scanner,
    /// which handles page batching and edge detection for long receipts.
    enum CaptureMode: String, CaseIterable { case single = "Single", multi = "Multi" }
    @State private var captureMode: CaptureMode = .single

    @State private var isExtracting = false
    @State private var parsedItems: [ParsedItem]?
    @State private var showDocumentScanner = false
    @State private var showManualEntry = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var confirmation: String?

    private let extractItems = ExtractBillItemsUseCase()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                viewfinder
                bottomPanel
            }

            if isExtracting { extractingOverlay }
        }
        .navigationBarHidden(true)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .fullScreenCover(isPresented: $showDocumentScanner) {
            DocumentScannerView { images in
                Task { await extract(from: images) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: Binding(
            get: { parsedItems.map { IdentifiedItems(items: $0) } },
            set: { if $0 == nil { parsedItems = nil } }
        )) { wrapper in
            ScannedItemsReviewSheet(items: wrapper.items) { savedCount in
                confirmation = savedCount > 0
                    ? "Added \(savedCount) expense\(savedCount == 1 ? "" : "s") from your bill."
                    : nil
            }
        }
        // Full screen rather than a sheet: the chooser grid now carries a proper header and
        // fills the page, not a half-height card.
        .fullScreenCover(isPresented: $showManualEntry) {
            AddExpenseBottomSheetView(itemToEdit: nil)
        }
        .photosPicker(isPresented: Binding(
            get: { photoPickerPresented },
            set: { if !$0 { photoPickerPresented = false } }
        ), selection: $photoSelection, matching: .images)
        .onChange(of: photoSelection) { _, item in
            guard let item else { return }
            Task { await extractFromLibrary(item) }
        }
        .alert("Bill Scanned", isPresented: Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )) {
            Button("Done") { confirmation = nil }
        } message: {
            Text(confirmation ?? "")
        }
    }

    @State private var photoPickerPresented = false

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            BackButton { dismiss() }

            Spacer()

            VStack(spacing: 3) {
                Text("Scan Bill")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.appGreen)
                    Text("Secure & Private")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 42, height: 42)
                    .background(Color.appSurface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
                Text("History")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
        // Off-white canvas, matching every other header in the app — the back/history
        // buttons keep their own white circles, which is what makes them read as controls
        // sitting on the page rather than being lost in a matching-white background.
        .background(Color.appBackground)
    }

    // MARK: - Viewfinder

    private var viewfinder: some View {
        ZStack {
            cameraLayer

            // Scrim keeps the white overlay controls legible over a bright receipt.
            LinearGradient(
                colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Inset far enough horizontally to clear the side controls, so the corner
            // marks never sit behind the Flash/Gallery/Help labels.
            ViewfinderFrame()
                .padding(.horizontal, 78)
                .padding(.top, 58)
                .padding(.bottom, 92)
                .allowsHitTesting(false)

            VStack {
                alignmentPill
                    .padding(.top, 14)

                Spacer()

                HStack(alignment: .bottom) {
                    sideControls
                    Spacer()
                    helpButton
                }
                .padding(.horizontal, 14)

                modePicker
                    .padding(.top, 12)
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .clipped()
    }

    @ViewBuilder
    private var cameraLayer: some View {
        switch camera.status {
        case .running:
            CameraPreviewView(session: camera.session)
        case .denied:
            unavailableLayer(
                icon: "video.slash.fill",
                title: "Camera access is off",
                message: "Enable camera access in Settings to scan bills.",
                showsSettingsLink: true
            )
        case .unavailable:
            unavailableLayer(
                icon: "camera.metering.unknown",
                title: "No camera available",
                message: "Use Upload Bill to pick a photo, or enter the expense manually."
            )
        case .failed(let reason):
            unavailableLayer(icon: "exclamationmark.triangle.fill", title: "Camera error", message: reason)
        case .idle:
            Color.black
        }
    }

    private func unavailableLayer(
        icon: String,
        title: String,
        message: String,
        showsSettingsLink: Bool = false
    ) -> some View {
        ZStack {
            Color(white: 0.12)
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.white.opacity(0.65))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(message)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)

                if showsSettingsLink {
                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.appGreen)
                    .padding(.top, 2)
                }
            }
        }
    }

    private var alignmentPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.appGreen)
                .frame(width: 8, height: 8)
            Text("Align bill within the frame")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
    }

    private var sideControls: some View {
        VStack(spacing: 14) {
            overlayButton(
                icon: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                label: "Flash",
                isActive: camera.isFlashOn
            ) {
                Haptics.light()
                camera.toggleFlash()
            }

            overlayButton(icon: "a.circle", label: "Auto") {
                Haptics.light()
            }

            overlayButton(icon: "photo", label: "Gallery") {
                Haptics.light()
                photoPickerPresented = true
            }
        }
    }

    private var helpButton: some View {
        overlayButton(icon: "questionmark", label: "Help") {
            Haptics.light()
        }
    }

    private func overlayButton(
        icon: String,
        label: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(isActive ? .appGreen : .white)
                    .frame(width: 46, height: 46)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                Button {
                    Haptics.light()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        captureMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(captureMode == mode ? .appGreenDeep : .white)
                        .frame(width: 84)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(captureMode == mode ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.5)))
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                aiExtractCard
                tipsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        // The shutter is the primary action — pinning it means it can never scroll
        // out of reach on a shorter device.
        .safeAreaInset(edge: .bottom) {
            actionRow
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color.appBackground)
        }
        // Off-white canvas, matching every other scrollable screen in the app — the AI-extract
        // and tip cards below carry their own white fill, which is what makes them read as
        // cards. This panel and its cards had the two swapped.
        .background(
            Color.appBackground
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var aiExtractCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.appGreen)
                .frame(width: 48, height: 48)
                .background(Color.appGreen.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("AI will extract details")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("We'll scan and extract merchant, items, amount and date for you.")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Image(systemName: AppIcon.Nav.forward)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.secondary.opacity(0.55))
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for best results")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    tipCard(
                        icon: "sun.max.fill",
                        tint: .appWarningAmber,
                        title: "Good Lighting",
                        detail: "Use natural light for best results"
                    )
                    tipCard(
                        icon: "doc.text.fill",
                        tint: .appGreen,
                        title: "Flat Surface",
                        detail: "Place bill on a flat surface"
                    )
                    tipCard(
                        icon: "viewfinder",
                        tint: Color(red: 59/255, green: 130/255, blue: 246/255),
                        title: "Avoid Blur",
                        detail: "Hold steady while capturing"
                    )
                    tipCard(
                        icon: "crop",
                        tint: .appGreen,
                        title: "Fit in Frame",
                        detail: "Keep the whole bill in frame"
                    )
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func tipCard(icon: String, tint: Color, title: String, detail: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)

            // Reserved to exactly two lines: every caption here runs two lines at this width,
            // so a shared height keeps all four cards level regardless of exact wrap points.
            Text(detail)
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        // A fixed width keeps every card the same size in the horizontal scroller; height is
        // left to size itself from content so a caption's second line can never be clipped by
        // the card's own rounded background — a fixed 132 sat right at that boundary and cut
        // descenders off under normal font metrics.
        .frame(width: 118, alignment: .top)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            secondaryAction(icon: "arrow.up.doc", title: "Upload Bill") {
                Haptics.light()
                photoPickerPresented = true
            }

            shutterButton

            secondaryAction(icon: "square.and.pencil", title: "Enter Manually") {
                Haptics.light()
                showManualEntry = true
            }
        }
    }

    private var shutterButton: some View {
        Button {
            Haptics.medium()
            Task { await capture() }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.appGreen.opacity(0.35), lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .fill(Color.appGreenDeep)
                    .frame(width: 64, height: 64)
                Image(systemName: AppIcon.Action.scan)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(camera.isCapturing || isExtracting)
        .opacity(camera.isCapturing || isExtracting ? 0.6 : 1)
    }

    private func secondaryAction(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            // A soft shadow, not a hairline border — the app's elevation system is shadow-only
            // (see CardStyles.swift), and this was the one control on the screen with a stroke.
            .liftedControl(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private var extractingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Reading your bill…")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(28)
            .background(Color.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Capture & extraction

    private func capture() async {
        // Multi-page receipts go through VisionKit, which batches and de-skews pages.
        guard captureMode == .single else {
            showDocumentScanner = true
            return
        }

        // No live camera (Simulator, denied) — fall back to picking an image.
        guard camera.status == .running else {
            photoPickerPresented = true
            return
        }

        guard let image = await camera.capturePhoto() else { return }
        await extract(from: [image])
    }

    private func extractFromLibrary(_ item: PhotosPickerItem) async {
        defer { photoSelection = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await extract(from: [image])
    }

    private func extract(from images: [UIImage]) async {
        guard !images.isEmpty else { return }
        isExtracting = true
        let items = await extractItems.execute(images: images)
        isExtracting = false
        // Always show the review sheet — an empty result still needs explaining.
        parsedItems = items
    }
}

/// `sheet(item:)` needs an `Identifiable` payload; `[ParsedItem]` isn't one.
private struct IdentifiedItems: Identifiable {
    let id = UUID()
    let items: [ParsedItem]
}

#Preview {
    ScanView()
}
