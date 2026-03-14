import SwiftUI
import AVFoundation

struct CameraView: View {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.permissionDenied {
                permissionDeniedView
            } else {
                CameraPreview(session: viewModel.session)
                    .ignoresSafeArea()

                VStack {
                    HStack {
                        Button {
                            viewModel.stopSession()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                        Spacer()
                        Button {
                            viewModel.toggleFlash()
                        } label: {
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                                .font(.title2)
                                .foregroundStyle(viewModel.isFlashOn ? .yellow : .white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding()
                    }

                    Spacer()

                    HStack(spacing: 48) {
                        Spacer()

                        Button {
                            viewModel.capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .stroke(.white.opacity(0.5), lineWidth: 3)
                                    .frame(width: 84, height: 84)
                            }
                        }

                        Button {
                            viewModel.toggleCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            viewModel.checkPermissionAndSetup()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .onChange(of: viewModel.capturedImageData) { _, data in
            guard let data else { return }
            onCapture(data)
            viewModel.stopSession()
            dismiss()
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.6))
            Text("Camera Access Required")
                .font(.title2).bold()
                .foregroundStyle(.white)
            Text("Please enable camera access in Settings to photograph your valuables.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.teal)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            Button("Cancel") { dismiss() }
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
