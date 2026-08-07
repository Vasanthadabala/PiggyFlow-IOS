import Foundation

/// Adapts `AppleSignInManager` to the `AuthRepository` contract.
///
/// The manager is an `ObservableObject` the views bind to directly; this wrapper exposes the
/// same session state to non-view code (use cases, sync) without dragging SwiftUI along, and
/// gives tests a protocol to stub.
@MainActor
final class AuthRepositoryImpl: AuthRepository {

    private let manager: AppleSignInManager
    private let userDefaults: UserDefaultsManager

    init(manager: AppleSignInManager, userDefaults: UserDefaultsManager = .shared) {
        self.manager = manager
        self.userDefaults = userDefaults
    }

    var isAuthenticated: Bool {
        manager.isAuthenticated || userDefaults.isLoggedIn
    }

    var currentUser: AuthenticatedUser? {
        guard isAuthenticated else { return nil }
        let appleUser = manager.user
        // Apple only returns the name on first authorization, so fall back to whatever the
        // user has since saved locally.
        let fullName = [appleUser?.firstName, appleUser?.lastName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return AuthenticatedUser(
            id: appleUser?.id ?? "",
            displayName: fullName.isEmpty ? userDefaults.username : fullName,
            email: appleUser?.email ?? userDefaults.userEmail
        )
    }

    func restoreSession() {
        manager.checkExistingCredentials()
    }

    func signOut() throws {
        manager.signOut()
        userDefaults.clearUserSession()
        Log.info("Signed out", category: .auth)
    }

    func deleteAccount() async throws {
        // `deleteAccount` is completion-based; bridge it so callers can `await`.
        let succeeded: Bool = await withCheckedContinuation { continuation in
            manager.deleteAccount { success in
                continuation.resume(returning: success)
            }
        }

        userDefaults.clearUserSession()

        guard succeeded else {
            throw AppError.authentication("Couldn't delete your account. Please sign in again and retry.")
        }
        Log.info("Account deleted", category: .auth)
    }
}
