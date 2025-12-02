import SwiftUI
import AuthenticationServices
import UIKit

struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Welcome to LittlePicto")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Sign in to save your creations or continue as a guest artist.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            
            VStack(spacing: 16) {
                TextField("Email address", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            
            VStack(spacing: 12) {
                Button {
                    focusedField = nil
                    Task {
                        await viewModel.signInWithEmailPassword()
                    }
                } label: {
                    Label("Sign In", systemImage: "person.crop.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
                
                Button {
                    focusedField = nil
                    Task {
                        await viewModel.registerWithEmailPassword()
                    }
                } label: {
                    Label("Create Account", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)
                
                Button {
                    focusedField = nil
                    Task {
                        await viewModel.signInAnonymously()
                    }
                } label: {
                    Label("Continue as Guest", systemImage: "hand.draw")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .disabled(viewModel.isProcessing)
            }

            thirdPartyButtons
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .overlay(alignment: .bottomTrailing) {
            if viewModel.isProcessing {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding()
            }
        }
    }
    
    private enum Field {
        case email
        case password
    }

    @ViewBuilder
    private var thirdPartyButtons: some View {
        VStack(spacing: 12) {
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.secondary.opacity(0.3))
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.secondary.opacity(0.3))
            }
            .padding(.vertical, 4)
            
            SignInWithAppleButton(.signIn) { request in
                focusedField = nil
                viewModel.prepareSignInWithAppleRequest(request)
            } onCompletion: { result in
                viewModel.handleSignInWithApple(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(viewModel.isProcessing)
            
            Button {
                focusedField = nil
                viewModel.signInWithGoogle(presenting: topViewController())
            } label: {
                HStack {
                    Image(systemName: "g.circle")
                        .font(.title3)
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.bordered)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(viewModel.isProcessing)
        }
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

