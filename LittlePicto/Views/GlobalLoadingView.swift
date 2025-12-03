import SwiftUI
import UIKit

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct GlobalLoadingView: View {
    @ObservedObject var loadingManager = LoadingManager.shared

    var body: some View {
        if loadingManager.isLoading {
            ZStack {
                VisualEffectBlur(blurStyle: .systemMaterialDark)
                    .edgesIgnoringSafeArea(.all)
                    .opacity(0.3)

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.8)

                    Text(String(localized: "loading"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(40)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
                .shadow(radius: 10)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: loadingManager.isLoading)
        }
    }
}
