import Foundation

/// Authentication contract.
///
/// The concrete implementations talk to Firebase Auth, Sign in with Apple and Google
/// Sign-In; use cases only see this, so sign-in flows can be exercised without a live
/// provider.
protocol AuthRepository {

    /// Whether a session is currently active.
    var isAuthenticated: Bool { get }

    /// The signed-in user, or `nil` when signed out.
    var currentUser: AuthenticatedUser? { get }

    /// Restores a session from stored credentials on launch.
    func restoreSession()

    /// Ends the session and clears local credentials.
    func signOut() throws

    /// Permanently deletes the remote account.
    func deleteAccount() async throws
}

/// The signed-in identity.
///
/// Deliberately minimal — Apple only returns a name and email on the *first* authorization,
/// so anything richer would be unreliable.
struct AuthenticatedUser: Equatable {
    let id: String
    let displayName: String?
    let email: String?

    /// Falls back through the available identifiers so the UI always has something to show.
    var resolvedDisplayName: String {
        if let displayName, !displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            return displayName
        }
        if let email, let localPart = email.split(separator: "@").first {
            return String(localPart)
        }
        return "You"
    }
}
