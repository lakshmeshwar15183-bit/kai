import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Production ``HTTPTransport`` backed by `URLSession`.
///
/// It is implemented with `dataTask` + a checked continuation rather than the
/// async `data(for:)` API so it behaves identically across macOS and Linux,
/// where the async URLSession surface has historically lagged.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 60) {
        self.session = session
        self.timeout = timeout
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: timeout)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    continuation.resume(throwing: AIProviderError.transportFailed(reason: error.localizedDescription))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: AIProviderError.transportFailed(reason: "non-HTTP response"))
                    return
                }
                continuation.resume(returning: HTTPResponse(statusCode: http.statusCode, body: data ?? Data()))
            }
            task.resume()
        }
    }
}
