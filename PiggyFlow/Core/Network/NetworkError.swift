import Foundation

/// Failure modes for `APIClient`.
enum NetworkError: LocalizedError, Equatable {
    /// The `Endpoint` could not be turned into a valid `URL`.
    case invalidURL
    /// The transport failed (offline, DNS, TLS, timeout…).
    case transport(String)
    /// A non-2xx response, carrying the status code and any decoded body text.
    case server(statusCode: Int, message: String?)
    /// The response body did not match the expected shape.
    case decoding(String)
    /// The request needs credentials that weren't present or were rejected.
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request address was invalid."
        case .transport(let message):
            return "Couldn't reach the server. \(message)"
        case .server(let statusCode, let message):
            return message ?? "The server returned an error (\(statusCode))."
        case .decoding(let message):
            return "Unexpected response from the server. \(message)"
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        }
    }

    /// Whether retrying the identical request could plausibly succeed.
    var isRetryable: Bool {
        switch self {
        case .transport:
            return true
        case .server(let statusCode, _):
            return statusCode >= 500 || statusCode == 429
        case .invalidURL, .decoding, .unauthorized:
            return false
        }
    }
}
