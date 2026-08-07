import Foundation

/// Transport for REST calls.
///
/// NOTE: the app's own backend traffic currently goes through the Firebase SDK
/// (`CloudSyncManager`), which owns its own networking. This client is the shared
/// foundation for any direct HTTP the app adds — receipt-scanning OCR, brand-logo
/// lookups, and similar — so those don't each hand-roll `URLSession` code.
protocol APIClientProtocol {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func send(_ endpoint: Endpoint) async throws -> Data
}

final class APIClient: APIClientProtocol {

    private let session: URLSession
    private let decoder: JSONDecoder
    private let interceptors: [Interceptor]

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        interceptors: [Interceptor] = [LoggingInterceptor()]
    ) {
        self.session = session
        self.decoder = decoder
        self.interceptors = interceptors
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        let data = try await send(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decoding(error.localizedDescription)
        }
    }

    @discardableResult
    func send(_ endpoint: Endpoint) async throws -> Data {
        var request = try endpoint.urlRequest()
        for interceptor in interceptors {
            request = try await interceptor.adapt(request)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.transport("The response was not valid HTTP.")
        }

        for interceptor in interceptors {
            try await interceptor.didReceive(http, data: data)
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401, 403:
            throw NetworkError.unauthorized
        default:
            throw NetworkError.server(
                statusCode: http.statusCode,
                message: String(data: data, encoding: .utf8)?.nilIfBlank
            )
        }
    }
}

private extension String {
    /// Avoids surfacing an empty body as a "message".
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
