import SwiftUI
import AVFoundation

struct SnapPhotoView: View {
    @StateObject private var camera = CameraViewModel()
    @State private var isAwaitingPhotoDecision = false
    @State private var isShowingCropper = false
    @SwiftUI.Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Camera Feed
            CameraPreviewViewForDrawingBook(previewLayer: camera.previewLayer)
                .ignoresSafeArea()
            
            // Fixed Square Scanner Frame (CalAi Style)
            FixedSquareScannerFrame()

            // Top Navigation Bar
            topBar

            // Bottom Toolbar
            bottomBar
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .sheet(isPresented: $isShowingCropper) {
            if let image = camera.capturedImage {
                PhotoCropperSheet(
                    image: image,
                    onCancel: handleCropCancel,
                    onConfirm: handleCropConfirm
                )
                .preferredColorScheme(.dark)
            } else {
                Text("No photo available")
                    .padding()
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    CircleButton(icon: "chevron.left")
                }

                Spacer()

                Text("Scanner")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: {}) {
                    CircleButton(icon: "ellipsis")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)

            Spacer()
        }
    }

    // MARK: - Bottom Bar
    private var bottomBar: some View {
        VStack {
            Spacer()

            scannerToolRow

            if isAwaitingPhotoDecision {
                photoConfirmationButtons
            } else {
//                ToolIconButton(icon: "photo") {
//                    triggerPhotoCapture()
//                }
            Button(action: triggerPhotoCapture) {
                CaptureButton()
                }
            }
            
//            .padding(.bottom, 35)
        }
    }

    private var scannerToolRow: some View {
        HStack(spacing: 18) {
            RoundedToolItem(icon: "fork.knife", text: "Scan")
            ToolIconButton(icon: "square.split.2x1")
//            if isAwaitingPhotoDecision {
//                photoConfirmationButtons
//            } else {
//                ToolIconButton(icon: "photo") {
//                    triggerPhotoCapture()
//                }
//            }
            ToolIconButton(icon: "pencil.tip")
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 10)
    }
    
    private var photoConfirmationButtons: some View {
        HStack(spacing: 8) {
            Button(action: confirmPhoto) {
                Label("Use photo", systemImage: "checkmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            
            Button(action: retakePhoto) {
                Label("Retake", systemImage: "arrow.uturn.left")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
    }
    
    private func triggerPhotoCapture() {
        camera.capturePhoto()
        isAwaitingPhotoDecision = true
    }
    
    private func confirmPhoto() {
        guard camera.capturedImage != nil else {
            isAwaitingPhotoDecision = false
            return
        }
        isAwaitingPhotoDecision = false
        isShowingCropper = true
    }
    
    private func retakePhoto() {
        camera.resetCapture()
        camera.start()
        isAwaitingPhotoDecision = false
    }

    private func handleCropCancel() {
        camera.resetCapture()
        camera.start()
    }

    private func handleCropConfirm(_ croppedImage: UIImage) {
        camera.saveCroppedPhoto(croppedImage) {
            camera.start()
        }
    }
}

struct RefinedScannerOverlay: View {
    @State private var offset: CGFloat = -140

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width * 0.75

            ZStack {
                // White scanning frame
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.8), lineWidth: 3)
                    .frame(width: size, height: size)

                // Scanning line
                Rectangle()
                    .fill(Color.green.opacity(0.9))
                    .frame(width: size * 0.9, height: 3)
                    .offset(y: offset)
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                            offset = size / 2
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
}


struct CircleButton: View {
    let icon: String
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)
            .padding(10)
            .background(.black.opacity(0.6))
            .clipShape(Circle())
    }
}

struct CaptureButton: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .frame(width: 80, height: 80)
                .foregroundColor(.white.opacity(0.9))

            Circle()
                .fill(Color.white)
                .frame(width: 60, height: 60)
        }
    }
}

struct ToolIconButton: View {
    let icon: String
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .padding(10)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct RoundedToolItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))

            Text(text)
                .font(.system(size: 14))
        }
        .foregroundColor(.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }
}


struct FixedSquareScannerFrame: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width * 0.75

            ZStack {
                // Invisible area, only showing the 4 corner lines
                Color.clear

                scannerCorners(size: size)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func scannerCorners(size: CGFloat) -> some View {
        let cornerLength: CGFloat = 30
        let thickness: CGFloat = 5

        ZStack {
            // TOP LEFT
            VStack(spacing: 0) {
                Rectangle().fill(.white).frame(width: thickness, height: cornerLength)
                Spacer()
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 - size/2,
                      y: UIScreen.main.bounds.height/2 - size/2)

            HStack(spacing: 0) {
                Rectangle().fill(.white).frame(width: cornerLength, height: thickness)
                Spacer()
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 - size/2,
                      y: UIScreen.main.bounds.height/2 - size/2)

            // TOP RIGHT
            VStack(spacing: 0) {
                Rectangle().fill(.white).frame(width: thickness, height: cornerLength)
                Spacer()
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 + size/2,
                      y: UIScreen.main.bounds.height/2 - size/2)

            HStack(spacing: 0) {
                Spacer()
                Rectangle().fill(.white).frame(width: cornerLength, height: thickness)
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 + size/2,
                      y: UIScreen.main.bounds.height/2 - size/2)

            // BOTTOM LEFT
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(.white).frame(width: thickness, height: cornerLength)
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 - size/2,
                      y: UIScreen.main.bounds.height/2 + size/2)

            HStack(spacing: 0) {
                Rectangle().fill(.white).frame(width: cornerLength, height: thickness)
                Spacer()
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 - size/2,
                      y: UIScreen.main.bounds.height/2 + size/2)

            // BOTTOM RIGHT
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(.white).frame(width: thickness, height: cornerLength)
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 + size/2,
                      y: UIScreen.main.bounds.height/2 + size/2)

            HStack(spacing: 0) {
                Spacer()
                Rectangle().fill(.white).frame(width: cornerLength, height: thickness)
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 + size/2,
                      y: UIScreen.main.bounds.height/2 + size/2)
        }
    }
}
