import Foundation
import FirebaseAuth
import FirebaseCore

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = true
    @Published private(set) var isProcessing = false
    @Published private(set) var errorMessage: String?
    
    private var authListener: AuthStateDidChangeListenerHandle?
    
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

extension AuthViewModel {
    enum AuthError: LocalizedError {
        case missingCredentials
    }
}

