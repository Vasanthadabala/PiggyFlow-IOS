import SwiftUI
import SwiftData
import AuthenticationServices
import CryptoKit
import Combine
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class AppleSignInManager: NSObject, ObservableObject {
    static let loginStatusKey = "isUserLoggedIn"
    @Published var isAuthenticated = false
    @Published var isAuthInProgress = false
    @Published var user: AppleUser?
    @Published var error: Error?
    @Published var authErrorMessage: String?
    
    private var currentNonce: String?
    #if canImport(FirebaseAuth)
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?
    #endif
    private var lastObservedUID: String?
    
    struct AppleUser {
        let id: String
        let email: String?
        let firstName: String?
        let lastName: String?
    }

    override init() {
        super.init()
        startAuthStateListener()
    }

    deinit {
        #if canImport(FirebaseAuth)
        if let authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(authStateListenerHandle)
        }
        #endif
    }
    
    // MARK: - Handle Apple Sign In
    func handleSignIn() {
        guard !isAuthInProgress else { return }
        authErrorMessage = nil
        isAuthInProgress = true
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    // MARK: - Handle Google Sign In (Firebase)
    func signInWithGoogle(presentingViewController: UIViewController) {
#if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(GoogleSignIn)
        guard !isAuthInProgress else { return }
        authErrorMessage = nil
        isAuthInProgress = true
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            authErrorMessage = "Firebase is not configured. Add GoogleService-Info.plist and call FirebaseApp.configure()."
            isAuthenticated = false
            UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
            isAuthInProgress = false
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            guard let self = self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.authErrorMessage = error.localizedDescription
                    self.isAuthenticated = false
                    UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
                    self.isAuthInProgress = false
                }
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                DispatchQueue.main.async {
                    self.authErrorMessage = "Unable to fetch Google auth token."
                    self.isAuthenticated = false
                    UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
                    self.isAuthInProgress = false
                }
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { authResult, error in
                DispatchQueue.main.async {
                    if let error {
                        self.authErrorMessage = error.localizedDescription
                        self.isAuthenticated = false
                        UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
                        self.isAuthInProgress = false
                        return
                    }

                    self.completeFirebaseSignIn(authResult: authResult)
                    self.isAuthInProgress = false
                }
            }
        }
#else
        authErrorMessage = "Google/Firebase SDKs are not installed in iOS target yet."
        isAuthenticated = false
        UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
        isAuthInProgress = false
#endif
    }
    
    // MARK: - Check if user already signed in
    func checkExistingCredentials() {
#if canImport(FirebaseAuth)
        if Auth.auth().currentUser != nil {
            isAuthenticated = true
            UserDefaults.standard.set(true, forKey: Self.loginStatusKey)
            CloudSyncManager.shared.handleLoginIfNeeded(context: DataManager.shared.localContainer.mainContext)
            return
        }
#endif

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        guard let userID = UserDefaults.standard.string(forKey: "appleUserID") else { return }
        
        appleIDProvider.getCredentialState(forUserID: userID) { [weak self] state, error in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    self?.isAuthenticated = true
                    UserDefaults.standard.set(true, forKey: Self.loginStatusKey)
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }
    
    func signOut() {
#if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch {
            print("Firebase signOut failed: \(error)")
        }
#endif

        CloudSyncManager.shared.handleLogout()

        // Reset authentication state
        isAuthenticated = false
        // Keep user in app flow even after logout.
        UserDefaults.standard.set(true, forKey: Self.loginStatusKey)
        user = nil
        authErrorMessage = nil
        isAuthInProgress = false

        // Remove Apple Sign-In user info
        let defaults = UserDefaults.standard
        [
            "appleUserID",
            "userEmail",
            "userFirstName",
            "userLastName",
        ].forEach { defaults.removeObject(forKey: $0) }
    }
    
    func deleteAccount(completion: @escaping (Bool) -> Void) {
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let currentUser = Auth.auth().currentUser else {
            completeAccountDeletion()
            completion(true)
            return
        }

        let uid = currentUser.uid
        Task {
            await self.deleteFirestoreBackup(uid: uid)
            await MainActor.run {
                currentUser.delete { [weak self] error in
                    guard let self else { return }
                    self.completeAccountDeletion()

                    if let error {
                        self.authErrorMessage = "Account removed locally, but cloud account deletion needs recent login. Please sign in again and retry."
                        print("❌ Firebase account delete failed: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("✅ Firebase account deleted")
                        completion(true)
                    }
                }
            }
        }
#else
        completeAccountDeletion()
        print("✅ Account data and auth state cleared")
        completion(true)
#endif
    }
    
    private func completeAccountDeletion() {
        // Step 1: Reset authentication state
        isAuthenticated = false
        UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
        user = nil

        // Step 2: Remove all user data and sync flags
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "appleUserID",
            "userEmail",
            "userFirstName",
            "userLastName"
        ]
        
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }

        CloudSyncManager.shared.handleLogout()
        clearKeychainItems()
    }

#if canImport(FirebaseFirestore)
    private func deleteFirestoreBackup(uid: String) async {
        let db = Firestore.firestore()
        let paths = [
            "users/\(uid)/expenses",
            "users/\(uid)/incomes",
            "users/\(uid)/trackers"
        ]

        for path in paths {
            do {
                let snapshot = try await db.collection(path).getDocuments()
                guard !snapshot.documents.isEmpty else { continue }
                let batch = db.batch()
                snapshot.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
            } catch {
                print("⚠️ Failed deleting Firestore path \(path): \(error.localizedDescription)")
            }
        }
    }
#endif
    
    private func clearKeychainItems() {
        // Clear any stored keychain items related to authentication
        let keychainItems = [
            kSecClassGenericPassword,
            kSecClassInternetPassword,
            kSecClassCertificate,
            kSecClassKey,
            kSecClassIdentity
        ]
        
        for keychainItem in keychainItems {
            let query: [String: Any] = [kSecClass as String: keychainItem]
            SecItemDelete(query as CFDictionary)
        }
    }

    private func persistUserDefaults(userID: String, email: String?, firstName: String?, lastName: String?) {
        UserDefaults.standard.set(userID, forKey: "appleUserID")

        if let email {
            UserDefaults.standard.set(email, forKey: "userEmail")
        }

        if let firstName, !firstName.isEmpty {
            UserDefaults.standard.set(firstName, forKey: "userFirstName")
            UserDefaults.standard.set(firstName, forKey: "appleUsername")
        } else if let existing = UserDefaults.standard.string(forKey: "appleUsername"), !existing.isEmpty {
            UserDefaults.standard.set(existing, forKey: "appleUsername")
        } else {
            UserDefaults.standard.set("Apple User", forKey: "appleUsername")
        }

        if let lastName {
            UserDefaults.standard.set(lastName, forKey: "userLastName")
        }
    }

    private func startAuthStateListener() {
        #if canImport(FirebaseAuth)
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            DispatchQueue.main.async {
                let currentUID = user?.uid
                self.isAuthenticated = currentUID != nil

                // Avoid re-triggering expensive sync for the same active user.
                guard self.lastObservedUID != currentUID else { return }
                self.lastObservedUID = currentUID

                if currentUID != nil {
                    CloudSyncManager.shared.handleLoginIfNeeded(context: DataManager.shared.localContainer.mainContext)
                } else {
                    CloudSyncManager.shared.handleLogout()
                }
            }
        }
        #endif
    }

#if canImport(FirebaseAuth)
    private func completeFirebaseSignIn(authResult: AuthDataResult?) {
        let isNewUser = authResult?.additionalUserInfo?.isNewUser ?? false
        let firebaseUser = authResult?.user

        isAuthenticated = firebaseUser != nil
        UserDefaults.standard.set(isAuthenticated, forKey: Self.loginStatusKey)
        authErrorMessage = nil

        if let name = firebaseUser?.displayName, !name.isEmpty {
            UserDefaults.standard.set(name, forKey: "appleUsername")
            UserDefaults.standard.set(name, forKey: "username")
        }

        if isAuthenticated {
            CloudSyncManager.shared.handleLoginIfNeeded(context: DataManager.shared.localContainer.mainContext)
        }

        print(isNewUser ? "✅ Firebase user created and signed in" : "✅ Existing Firebase user signed in")
    }
#endif
    
    // MARK: - Security Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if status != errSecSuccess {
                    fatalError("Unable to generate nonce.")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 { return }
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
        return SHA256.hash(data: inputData).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Delegate
extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userID = credential.user
            let email = credential.email
            let firstName = credential.fullName?.givenName
            let lastName = credential.fullName?.familyName

#if canImport(FirebaseAuth)
            guard
                let nonce = currentNonce,
                let appleIDToken = credential.identityToken,
                let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else {
                DispatchQueue.main.async {
                    self.authErrorMessage = "Unable to read Apple credential token."
                    self.isAuthenticated = false
                    UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
                    self.isAuthInProgress = false
                }
                return
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            Auth.auth().signIn(with: firebaseCredential) { [weak self] authResult, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let error {
                        self.error = error
                        self.authErrorMessage = error.localizedDescription
                        self.isAuthenticated = false
                        UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
                        self.isAuthInProgress = false
                        return
                    }

                    self.user = AppleUser(
                        id: userID,
                        email: email ?? authResult?.user.email,
                        firstName: firstName,
                        lastName: lastName
                    )
                    self.completeFirebaseSignIn(authResult: authResult)
                    self.persistUserDefaults(
                        userID: userID,
                        email: email ?? authResult?.user.email,
                        firstName: firstName,
                        lastName: lastName
                    )
                    self.isAuthInProgress = false
                }
            }
#else
            let user = AppleUser(
                id: userID,
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            
            DispatchQueue.main.async {
                self.user = user
                self.isAuthenticated = true
                UserDefaults.standard.set(true, forKey: Self.loginStatusKey)
                self.error = nil
                self.authErrorMessage = nil
                self.persistUserDefaults(
                    userID: userID,
                    email: email,
                    firstName: firstName,
                    lastName: lastName
                )
                self.isAuthInProgress = false
            }
#endif
        } else {
            DispatchQueue.main.async {
                self.authErrorMessage = "Unable to read Apple account credentials."
                self.isAuthenticated = false
                UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
                self.isAuthInProgress = false
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.error = error
            self.authErrorMessage = error.localizedDescription
            self.isAuthenticated = false
            UserDefaults.standard.set(false, forKey: Self.loginStatusKey)
            self.isAuthInProgress = false
            print("Sign in with Apple error: \(error)")
        }
    }
}
