// FILE: QRScannerView.swift
// Purpose: AVFoundation camera-based QR scanner for Mac companion pairing.
// Layer: View
// Exports: QRScannerView
// Depends on: SwiftUI, AVFoundation

import AVFoundation
import SwiftUI

struct QRScannerView: View {
    let onScan: (String) -> Void

    @State private var scannerError: String?
    @State private var hasCameraPermission = false
    @State private var isCheckingPermission = true

    var body: some View {
        ZStack {
            CodexBrand.ink.ignoresSafeArea()

            if isCheckingPermission {
                ProgressView()
                    .tint(.white)
            } else if hasCameraPermission {
                QRCameraPreview { code, resetScanLock in
                    handleScanResult(code, resetScanLock: resetScanLock)
                }
                .ignoresSafeArea()

                scannerOverlay
            } else {
                cameraPermissionView
            }
        }
        .task {
            await checkCameraPermission()
        }
        .alert("Scan Error", isPresented: Binding(
            get: { scannerError != nil },
            set: { if !$0 { scannerError = nil } }
        )) {
            Button("OK", role: .cancel) { scannerError = nil }
        } message: {
            Text(scannerError ?? "Invalid QR code")
        }
    }

    private var scannerOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            RoundedRectangle(cornerRadius: 20)
                .stroke(CodexBrand.accentSoft.opacity(0.8), lineWidth: 2)
                .frame(width: 250, height: 250)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.04))
                )

            Text("Scan a QR with your server URL")
                .font(AppFont.subheadline(weight: .medium))
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private var cameraPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Camera access needed")
                .font(AppFont.title3(weight: .semibold))
                .foregroundStyle(.white)

            Text("Open Settings and allow camera access to scan a QR code containing your server URL from your Mac.")
                .font(AppFont.subheadline())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            hasCameraPermission = await AVCaptureDevice.requestAccess(for: .video)
        default:
            hasCameraPermission = false
        }
        isCheckingPermission = false
    }

    private func handleScanResult(_ code: String, resetScanLock: @escaping () -> Void) {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directURL = directServerURL(from: trimmedCode) {
            onScan(directURL)
            return
        }

        guard let data = code.data(using: .utf8) else {
            scannerError = "QR code contains invalid text encoding."
            resetScanLock()
            return
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let json = jsonObject as? [String: Any] else {
            scannerError = "Not a valid server QR. Scan a QR containing a ws:// or wss:// server URL."
            resetScanLock()
            return
        }

        if let directURL = firstDirectURL(in: json),
           let normalizedDirectURL = directServerURL(from: directURL) {
            onScan(normalizedDirectURL)
            return
        }

        scannerError = "QR code is missing a usable server URL. Include a ws:// or wss:// address."
        resetScanLock()
    }

    private func directServerURL(from candidate: String) -> String? {
        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedCandidate),
              let scheme = url.scheme?.lowercased(),
              (scheme == "ws" || scheme == "wss"),
              url.host?.isEmpty == false else {
            return nil
        }

        return trimmedCandidate
    }

    private func firstDirectURL(in json: [String: Any]) -> String? {
        let candidateKeys = ["serverURL", "serverUrl", "appServer", "url", "wsURL", "wsUrl"]
        for key in candidateKeys {
            if let value = json[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}

// MARK: - Camera Preview UIViewRepresentable

private struct QRCameraPreview: UIViewRepresentable {
    let onScan: (String, _ resetScanLock: @escaping () -> Void) -> Void

    func makeUIView(context: Context) -> QRCameraUIView {
        let view = QRCameraUIView()
        view.onScan = { [weak view] code in
            onScan(code) {
                view?.resetScanLock()
            }
        }
        return view
    }

    func updateUIView(_ uiView: QRCameraUIView, context: Context) {}
}

private class QRCameraUIView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.minidex.qr-camera")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCamera()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        previewLayer = layer

        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let code = object.stringValue else {
            return
        }

        hasScanned = true
        HapticFeedback.shared.triggerImpactFeedback(style: .heavy)
        onScan?(code)
    }

    func resetScanLock() {
        hasScanned = false
    }

    deinit {
        let session = captureSession
        sessionQueue.async {
            session.stopRunning()
        }
    }
}
