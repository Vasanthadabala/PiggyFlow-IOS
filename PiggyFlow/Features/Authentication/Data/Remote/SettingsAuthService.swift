import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import SwiftData
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Google / Apple sign-in used by the Settings screen to link a cloud account to an
/// existing local session.
///
/// Distinct from `AppleSignInManager`, which owns the *app-level* auth state used by
/// `ContentView` to decide between onboarding and the main tab bar. This one only performs
/// the linking flow and reports progress/errors back to Settings.
final class SettingsAuthService: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    @Published var isAuthInProgress = false
    @Published var authErrorMessage: String?

    private var currentNonce: String?

    func signInWithGoogle(presentingViewController: UIViewController) {
        guard !isAuthInProgress else { return }
        authErrorMessage = nil
        isAuthInProgress = true

#if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(GoogleSignIn)
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            fail("Firebase is not configured. Add GoogleService-Info.plist and call FirebaseApp.configure().")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.fail(error.localizedDescription)
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                self.fail("Unable to fetch Google auth token.")
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self else { return }
                if let error {
                    self.fail(error.localizedDescription)
                    return
                }
                self.completeSuccess(displayName: authResult?.user.displayName, email: authResult?.user.email)
            }
        }
#else
        fail("Google/Firebase SDKs are not installed in iOS target yet.")
#endif
    }

    func signInWithApple() {
        guard !isAuthInProgress else { return }
        authErrorMessage = nil
        isAuthInProgress = true

        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            fail("Unable to read Apple account credentials.")
            return
        }

#if canImport(FirebaseAuth)
        guard
            let nonce = currentNonce,
            let tokenData = credential.identityToken,
            let idTokenString = String(data: tokenData, encoding: .utf8)
        else {
            fail("Unable to read Apple credential token.")
            return
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        Auth.auth().signIn(with: firebaseCredential) { [weak self] authResult, error in
            guard let self else { return }
            if let error {
                self.fail(error.localizedDescription)
                return
            }
            let givenName = credential.fullName?.givenName
            self.completeSuccess(
                displayName: givenName?.isEmpty == false ? givenName : authResult?.user.displayName,
                email: credential.email ?? authResult?.user.email
            )
        }
#else
        completeSuccess(displayName: credential.fullName?.givenName, email: credential.email)
#endif
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        fail(error.localizedDescription)
    }

    private func completeSuccess(displayName: String?, email: String?) {
        DispatchQueue.main.async {
            if let displayName, !displayName.isEmpty {
                UserDefaults.standard.set(displayName, forKey: "username")
            }
            if let email, !email.isEmpty {
                UserDefaults.standard.set(email, forKey: "userEmail")
            }
            UserDefaults.standard.set(true, forKey: AppleSignInManager.loginStatusKey)
            CloudSyncManager.shared.handleLoginIfNeeded(context: DataManager.shared.localContainer.mainContext)
            self.authErrorMessage = nil
            self.isAuthInProgress = false
        }
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async {
            self.authErrorMessage = message
            self.isAuthInProgress = false
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
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
