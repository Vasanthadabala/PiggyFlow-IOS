import Foundation

/// A single API route, described declaratively so callers never hand-build `URLRequest`s.
struct Endpoint {
    var baseURL: URL
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Data?

    init(
        baseURL: URL,
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }

    /// Convenience for a JSON body; also sets `Content-Type`.
    static func json<T: Encodable>(
        baseURL: URL,
        path: String,
        method: HTTPMethod,
        payload: T,
        headers: [String: String] = [:],
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> Endpoint {
        var merged = headers
        merged["Content-Type"] = "application/json"
        return Endpoint(
            baseURL: baseURL,
            path: path,
            method: method,
            headers: merged,
            body: try encoder.encode(payload)
        )
    }

    /// Builds the `URLRequest`, or throws `NetworkError.invalidURL` if the pieces don't
    /// form a valid URL.
    func urlRequest() throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
}
