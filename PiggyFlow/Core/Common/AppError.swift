import Foundation

/// The single error type surfaced to the presentation layer.
///
/// Lower layers throw their own concrete errors (`NetworkError`, `Keychain` status codes,
/// SwiftData failures); they get mapped into this so views only ever have to render one
/// shape, and so `errorDescription` is always safe to show to a user.
enum AppError: LocalizedError, Equatable {
    /// A network request failed.
    case network(NetworkError)
    /// Reading or writing local persistence failed.
    case persistence(String)
    /// Sign-in / token refresh failed.
    case authentication(String)
    /// User input failed validation.
    case validation(String)
    /// Anything that doesn't fit the cases above.
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network(let underlying):
            return underlying.errorDescription
        case .persistence(let message):
            return message
        case .authentication(let message):
            return message
        case .validation(let message):
            return message
        case .unknown(let message):
            return message
        }
    }

    /// Short, user-facing title suitable for an alert.
    var title: String {
        switch self {
        case .network: return "Connection Problem"
        case .persistence: return "Save Failed"
        case .authentication: return "Sign-In Failed"
        case .validation: return "Check Your Input"
        case .unknown: return "Something Went Wrong"
        }
    }

    /// Wraps an arbitrary `Error` without losing an already-typed `AppError`.
    static func wrap(_ error: Error) -> AppError {
        if let appError = error as? AppError { return appError }
        if let networkError = error as? NetworkError { return .network(networkError) }
        return .unknown(error.localizedDescription)
    }
}
