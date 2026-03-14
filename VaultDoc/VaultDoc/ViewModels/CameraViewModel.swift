import SwiftUI
@preconcurrency import AVFoundation

@MainActor
@Observable
class CameraViewModel: NSObject {
    var capturedImageData: Data? = nil
    var isFlashOn = false
    var isFrontCamera = false
    var permissionDenied = false

    var session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "VaultDoc.CameraSessionQueue")

    func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.setupSession()
                    } else {
                        self.permissionDenied = true
                    }
                }
            }
        default:
            permissionDenied = true
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if let existing = currentInput {
            session.removeInput(existing)
        }
        if session.canAddInput(input) { session.addInput(input) }
        currentInput = input

        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        session.commitConfiguration()

        let session = session
        sessionQueue.async {
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(isFlashOn ? .on : .off) {
            settings.flashMode = isFlashOn ? .on : .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func toggleFlash() { isFlashOn.toggle() }

    func toggleCamera() {
        isFrontCamera.toggle()
        setupSession()
    }

    func stopSession() {
        let session = session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation() else { return }
        capturedImageData = data
    }
}
