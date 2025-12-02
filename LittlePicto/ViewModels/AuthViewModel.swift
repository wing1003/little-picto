import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit
import Security

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = true
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    
    private var authListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        attachAuthStateListener()
    }
    
    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
        }
    }
    
    func signInWithEmailPassword() async {
        await runAuthAction {
            guard email.isEmpty == false, password.isEmpty == false else {
                throw AuthError.missingCredentials
            }
            return try await Auth.auth().signIn(withEmail: email, password: password)
        }
    }
    
    func registerWithEmailPassword() async {
        await runAuthAction {
            guard email.isEmpty == false, password.isEmpty == false else {
                throw AuthError.missingCredentials
            }
            return try await Auth.auth().createUser(withEmail: email, password: password)
        }
    }
    
    func signInAnonymously() async {
        await runAuthAction {
            try await Auth.auth().signInAnonymously()
        }
    }
    
    func prepareSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce
            else {
                errorMessage = "Unable to process Apple ID credentials."
                return
            }
            guard
                let appleIDToken = appleIDCredential.identityToken,
                let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else {
                errorMessage = "Unable to read Apple ID token."
                return
            }
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString, rawNonce: nonce, fullName: appleIDCredential.fullName)
            Task {
                await self.runAuthAction {
                    try await Auth.auth().signIn(with: credential)
                }
            }
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func signInWithGoogle(presenting viewController: UIViewController?) {
        guard isProcessing == false else { return }
        errorMessage = nil
        
        guard let viewController else {
            errorMessage = "Unable to present Google Sign In."
            return
        }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Missing Google client ID."
            return
        }
        
        isProcessing = true
        
        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration
        
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { [weak self] result, error in
            guard let self else { return }
            self.isProcessing = false
            
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            
            guard
                let result,
                let idToken = result.user.idToken?.tokenString
            else {
                self.errorMessage = "Unable to retrieve Google tokens."
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            Task {
                await self.runAuthAction {
                    try await Auth.auth().signIn(with: credential)
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            email = ""
            password = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    var userDisplayName: String {
        if let user = currentUser {
            if let email = user.email, email.isEmpty == false {
                return email
            }
            return user.isAnonymous ? "Guest Artist" : "LittlePicto Artist"
        }
        return "Guest Artist"
    }
    
    private func attachAuthStateListener() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            self.currentUser = user
            self.isLoading = false
            guard user != nil else { return }
            self.errorMessage = nil
            self.email = ""
            self.password = ""
        }
    }
    
    private func runAuthAction(_ action: () async throws -> AuthDataResult) async {
        guard isProcessing == false else { return }
        isProcessing = true
        errorMessage = nil
        do {
            _ = try await action()
        } catch AuthError.missingCredentials {
            errorMessage = "Please enter both an email address and a password."
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
}

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    
    while remainingLength > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        randoms.forEach { random in
            if remainingLength == 0 {
                return
            }
            
            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }
    
    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.map { String(format: "%02x", $0) }.joined()
}

extension AuthViewModel {
    enum AuthError: LocalizedError {
        case missingCredentials
    }
}

