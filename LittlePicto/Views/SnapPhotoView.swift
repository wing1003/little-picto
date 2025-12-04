import SwiftUI
import AVFoundation

// MARK: - Snap Photo View

struct SnapPhotoView: View {
    @StateObject private var camera = CameraViewModel()
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var isAwaitingPhotoDecision = false
    @State private var isShowingCropper = false
    @State private var sparkleAnimation = false
    @State private var quotaInfo: QuotaInfo?
    
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    private let quotaManager = QuotaManager()
    
    var body: some View {
        ZStack {
            // Camera Feed
            CameraPreviewViewForDrawingBook(previewLayer: camera.previewLayer)
                .ignoresSafeArea()
            
            // Fun Sparkly Scanner Frame
            FunScannerFrame()
            
            // Top Navigation Bar
            topBar
            
            // Bottom Toolbar
            bottomBar
        }
        .task {
            camera.start()
            sparkleAnimation = true
            await refreshQuotaInfo()
        }
        .onDisappear {
            camera.stop()
        }
        .sheet(isPresented: $isShowingCropper) {
            if let image = camera.capturedImage {
                PhotoCropperSheet(
                    image: image,
                    onCancel: handleCropCancel,
                    onConfirm: handleCropConfirm
                )
                .preferredColorScheme(.dark)
            } else {
                Text("Oops! No photo yet 📸")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    FunCircleButton(icon: "arrow.left", color: .purple)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.headline)
                        Text("Photo Time!")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    
                    // Quota indicator
                    if let quota = quotaInfo, subscriptionManager.isPremium {
                        HStack(spacing: 4) {
                            Image(systemName: quotaIcon(for: quota))
                                .font(.caption2)
                            Text("\(quota.remaining) left")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(quotaColor(for: quota))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                
                Spacer()
                
                Button(action: {
                    Task { await refreshQuotaInfo() }
                }) {
                    FunCircleButton(icon: "arrow.clockwise", color: .pink)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 15)
            
            Spacer()
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if !isAwaitingPhotoDecision {
                funToolTip
            }
            
            if isAwaitingPhotoDecision {
                photoConfirmationButtons
            } else {
                Button(action: triggerPhotoCapture) {
                    FunCaptureButton()
                }
            }
        }
        .padding(.bottom, 40)
    }
    
    private var funToolTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.point.down.fill")
                .font(.title3)
            Text("Tap the button to snap!")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.yellow.opacity(0.6), lineWidth: 2)
        )
        .shadow(color: .yellow.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private var photoConfirmationButtons: some View {
        VStack(spacing: 12) {
            Text("Do you like this photo? 🤔")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            
            HStack(spacing: 16) {
                Button(action: confirmPhoto) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.title3)
                        Text("Yes! Use it!")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .green.opacity(0.5), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(BounceButtonStyle())
                
                Button(action: retakePhoto) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                        Text("Try Again")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.5), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Actions
    
    private func triggerPhotoCapture() {
        let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
        impactHeavy.impactOccurred()
        
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
        Task {
            // Record the usage in quota manager
            let tier = subscriptionManager.currentSubscriptionTier
            do {
                _ = try await quotaManager.checkAndConsumeQuota(for: tier)
                await refreshQuotaInfo()
            } catch {
                print("Failed to record quota usage: \(error)")
            }
            
            // Save the photo
            camera.saveCroppedPhoto(croppedImage) {
                camera.start()
            }
        }
    }
    
    private func refreshQuotaInfo() async {
        let tier = subscriptionManager.currentSubscriptionTier
        
        guard tier != .free else {
            quotaInfo = nil
            return
        }
        
        do {
            let (used, limit, remaining) = try await quotaManager.getCurrentQuota(for: tier)
            quotaInfo = QuotaInfo(
                tier: tier,
                used: used,
                remaining: remaining,
                limit: limit
            )
        } catch {
            print("Failed to fetch quota info: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func quotaIcon(for info: QuotaInfo) -> String {
        if info.isAtLimit {
            return "exclamationmark.circle.fill"
        } else if info.isNearLimit {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private func quotaColor(for info: QuotaInfo) -> Color {
        if info.isAtLimit {
            return .red
        } else if info.isNearLimit {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Fun Circle Button

struct FunCircleButton: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.white)
            .padding(12)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
            .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Fun Capture Button

struct FunCaptureButton: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 5
                )
                .frame(width: 90, height: 90)
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .opacity(isPulsing ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
            
            // Middle ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                .frame(width: 85, height: 85)
            
            // Inner button
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 70, height: 70)
                .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
            
            // Camera icon
            Image(systemName: "camera.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Fun Scanner Frame

struct FunScannerFrame: View {
    @State private var scanAnimation = false
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width * 0.75
            
            ZStack {
                // Rounded corner brackets
                funScannerCorners(size: size)
                
                // Animated scanning line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .purple.opacity(0.8), .pink.opacity(0.8), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.9, height: 3)
                    .offset(y: scanAnimation ? size / 2 : -size / 2)
                    .blur(radius: 1)
                    .onAppear {
                        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                            scanAnimation = true
                        }
                    }
                
                // Sparkle effects at corners
                ForEach(0..<4, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: 16))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .position(cornerPosition(for: index, size: size, screenSize: geo.size))
                        .opacity(0.8)
                        .scaleEffect(scanAnimation ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(Double(index) * 0.2), value: scanAnimation)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
    }
    
    private func cornerPosition(for index: Int, size: CGFloat, screenSize: CGSize) -> CGPoint {
        let centerX = screenSize.width / 2
        let centerY = screenSize.height / 2
        let offset = size / 2 + 10
        
        switch index {
        case 0: return CGPoint(x: centerX - offset, y: centerY - offset) // Top-left
        case 1: return CGPoint(x: centerX + offset, y: centerY - offset) // Top-right
        case 2: return CGPoint(x: centerX - offset, y: centerY + offset) // Bottom-left
        default: return CGPoint(x: centerX + offset, y: centerY + offset) // Bottom-right
        }
    }
    
    @ViewBuilder
    private func funScannerCorners(size: CGFloat) -> some View {
        let cornerLength: CGFloat = 35
        let thickness: CGFloat = 6
        let cornerRadius: CGFloat = 8
        
        ZStack {
            // TOP LEFT
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: thickness, height: cornerLength)
                Spacer()
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 - size/2,
                      y: UIScreen.main.bounds.height/2 - size/2)
            
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: cornerLength, height: thickness)
                Spacer()
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 - size/2,
                      y: UIScreen.main.bounds.height/2 - size/2)
            
            // TOP RIGHT
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: thickness, height: cornerLength)
                Spacer()
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 + size/2,
                      y: UIScreen.main.bounds.height/2 - size/2)
            
            HStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: cornerLength, height: thickness)
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 + size/2,
                      y: UIScreen.main.bounds.height/2 - size/2)
            
            // BOTTOM LEFT
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: thickness, height: cornerLength)
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 - size/2,
                      y: UIScreen.main.bounds.height/2 + size/2)
            
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: cornerLength, height: thickness)
                Spacer()
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 - size/2,
                      y: UIScreen.main.bounds.height/2 + size/2)
            
            // BOTTOM RIGHT
            VStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: thickness, height: cornerLength)
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 + size/2,
                      y: UIScreen.main.bounds.height/2 + size/2)
            
            HStack(spacing: 0) {
                Spacer()
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: cornerLength, height: thickness)
            }
            .frame(width: cornerLength, height: cornerLength)
            .position(x: UIScreen.main.bounds.width/2 + size/2,
                      y: UIScreen.main.bounds.height/2 + size/2)
        }
        .shadow(color: .purple.opacity(0.6), radius: 8, x: 0, y: 0)
    }
}

// MARK: - Preview

#Preview {
    SnapPhotoView()
        .environmentObject(SubscriptionManager.shared)
}
