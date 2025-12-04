import SwiftUI
import AuthenticationServices
import UIKit

struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    @State private var bounceAnimation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                heroSection
                
                VStack(spacing: 20) {
//                    inputFields
//                    actionButtons
                    thirdPartyButtons
                }
                
                if let error = viewModel.errorMessage {
                    errorMessageView(error)
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isProcessing {
                loadingIndicator
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                // Decorative circles
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                // Main icon
                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(-15))
                    .scaleEffect(bounceAnimation ? 1.1 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).repeatForever(autoreverses: true), value: bounceAnimation)
                    .onAppear { bounceAnimation = true }
                
                // Sparkles
                Image(systemName: "sparkle")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .offset(x: -40, y: -40)
                    .opacity(bounceAnimation ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: bounceAnimation)
                
                Image(systemName: "sparkle")
                    .font(.title3)
                    .foregroundStyle(.pink)
                    .offset(x: 45, y: -35)
                    .opacity(bounceAnimation ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(0.3), value: bounceAnimation)
                
                Image(systemName: "sparkle")
                    .font(.title)
                    .foregroundStyle(.purple)
                    .offset(x: 35, y: 40)
                    .opacity(bounceAnimation ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(0.6), value: bounceAnimation)
            }
            .frame(height: 160)
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                Text("Welcome to LittlePicto! 🎨")
                    .font(.system(size: 32, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
//                Text("Sign in to save your amazing art, or jump right in as a guest!")
                Text("Sign in to save your amazing art!")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Input Fields
    private var inputFields: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 24)
                
                TextField("Your email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(focusedField == .email ? Color.purple : Color.clear, lineWidth: 2)
            )
            
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.pink)
                    .frame(width: 24)
                
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(focusedField == .password ? Color.pink : Color.clear, lineWidth: 2)
            )
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                focusedField = nil
                Task {
                    await viewModel.signInWithEmailPassword()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                    Text("Let's Go!")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(BounceButtonStyle())
            .disabled(viewModel.isProcessing)
            
            Button {
                focusedField = nil
                Task {
                    await viewModel.registerWithEmailPassword()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                    Text("Create My Account")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground))
                .foregroundStyle(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
            }
            .buttonStyle(BounceButtonStyle())
            .disabled(viewModel.isProcessing)
            
            Button {
                focusedField = nil
                Task {
                    await viewModel.signInAnonymously()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.wave")
                        .font(.headline)
                    Text("Just Start Drawing!")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(BounceButtonStyle())
            .disabled(viewModel.isProcessing)
        }
    }
    
    // MARK: - Third Party Buttons
    @ViewBuilder
    private var thirdPartyButtons: some View {
        VStack(spacing: 16) {
//            HStack(spacing: 12) {
//                Rectangle()
//                    .frame(height: 2)
//                    .foregroundStyle(.secondary.opacity(0.3))
//                
//                HStack(spacing: 10) {
//                    Image(systemName: "sparkles")
//                        .font(.caption)
//                    Text("or use")
//                        .font(.subheadline)
//                        .fontWeight(.medium)
//                    Image(systemName: "sparkles")
//                        .font(.caption)
//                }
//                .foregroundStyle(.secondary)
//                
//                Rectangle()
//                    .frame(height: 2)
//                    .foregroundStyle(.secondary.opacity(0.3))
//            }
//            .padding(.vertical, 8)
            
            SignInWithAppleButton(.signIn) { request in
                focusedField = nil
                viewModel.prepareSignInWithAppleRequest(request)
            } onCompletion: { result in
                viewModel.handleSignInWithApple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .disabled(viewModel.isProcessing)
            
            Button {
                focusedField = nil
                viewModel.signInWithGoogle(presenting: topViewController())
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text("Sign in with Google")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(BounceButtonStyle())
            .disabled(viewModel.isProcessing)
        }
    }
    
    // MARK: - Error Message
    private func errorMessageView(_ error: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Loading Indicator
    private var loadingIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.purple)
            Text("Just a sec...")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding()
    }
    
    private enum Field {
        case email
        case password
    }

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })?
            .rootViewController
        
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}


#Preview {
    AuthenticationView(viewModel: AuthViewModel())
}
