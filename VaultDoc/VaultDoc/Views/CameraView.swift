import SwiftUI
import AVFoundation

struct CameraView: View {
    var onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageSettings.self) private var language
    @State private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            BrandTheme.backgroundGradient.ignoresSafeArea()

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
                                .foregroundStyle(BrandTheme.textPrimary)
                                .padding(12)
                                .background(Circle().fill(BrandTheme.surface))
                        }
                        .padding()
                        Spacer()
                        Button {
                            viewModel.toggleFlash()
                        } label: {
                            Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash")
                                .font(.title2)
                                .foregroundStyle(viewModel.isFlashOn ? BrandTheme.accentBright : BrandTheme.textPrimary)
                                .padding(12)
                                .background(Circle().fill(BrandTheme.surface))
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
                                    .fill(BrandTheme.accentGradient)
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .stroke(BrandTheme.border, lineWidth: 3)
                                    .frame(width: 84, height: 84)
                            }
                        }

                        Button {
                            viewModel.toggleCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title)
                                .foregroundStyle(BrandTheme.textPrimary)
                                .padding(12)
                                .background(Circle().fill(BrandTheme.surface))
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
                .foregroundStyle(BrandTheme.textSecondary)
            Text(L10n.tr("camera.permission_required"))
                .font(.title2).bold()
                .foregroundStyle(BrandTheme.textPrimary)
            Text(L10n.tr("camera.permission_message"))
                .multilineTextAlignment(.center)
                .foregroundStyle(BrandTheme.textSecondary)
                .padding(.horizontal)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L10n.tr("camera.open_settings"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(BrandTheme.accentGradient)
                    .foregroundStyle(BrandTheme.backgroundBottom)
                    .clipShape(Capsule())
            }
            Button(L10n.tr("common.cancel")) { dismiss() }
                .foregroundStyle(BrandTheme.textSecondary)
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
