import Foundation

/// A hook that can rewrite outgoing requests and inspect incoming responses.
///
/// Interceptors let cross-cutting concerns (auth headers, logging, retry) live outside
/// `APIClient` so the client itself stays a thin transport.
protocol Interceptor {
    /// Called before the request is sent. Return the (possibly modified) request.
    func adapt(_ request: URLRequest) async throws -> URLRequest

    /// Called after a response arrives. Throw to convert it into a failure.
    func didReceive(_ response: HTTPURLResponse, data: Data) async throws
}

extension Interceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest { request }
    func didReceive(_ response: HTTPURLResponse, data: Data) async throws {}
}

/// Attaches a bearer token to every request.
struct AuthTokenInterceptor: Interceptor {
    /// Resolved per-request so a refreshed token is always picked up.
    let tokenProvider: () async -> String?

    func adapt(_ request: URLRequest) async throws -> URLRequest {
        guard let token = await tokenProvider() else { return request }
        var adapted = request
        adapted.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return adapted
    }
}

/// Logs request/response lines through `Log`.
struct LoggingInterceptor: Interceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        Log.debug("→ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")", category: .network)
        return request
    }

    func didReceive(_ response: HTTPURLResponse, data: Data) async throws {
        Log.debug("← \(response.statusCode) (\(data.count) bytes)", category: .network)
    }
}
