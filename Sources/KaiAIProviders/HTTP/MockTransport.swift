import Foundation

/// A deterministic ``HTTPTransport`` for tests. It records every request it
/// receives and replies with a queued (or default) response, so provider
/// request-shaping and response-parsing can be verified without a network.
public actor MockTransport: HTTPTransport {
    public private(set) var requests: [HTTPRequest] = []
    private var queue: [HTTPResponse]
    private let defaultResponse: HTTPResponse

    /// - Parameters:
    ///   - responses: Responses returned in order; once exhausted, `defaultResponse` is used.
    ///   - defaultResponse: Fallback response (defaults to an empty 200).
    public init(responses: [HTTPResponse] = [], defaultResponse: HTTPResponse = HTTPResponse(statusCode: 200, body: Data())) {
        self.queue = responses
        self.defaultResponse = defaultResponse
    }

    /// Convenience initialiser returning a single JSON string body with a status.
    public init(json: String, status: Int = 200) {
        self.queue = [HTTPResponse(statusCode: status, body: Data(json.utf8))]
        self.defaultResponse = HTTPResponse(statusCode: status, body: Data(json.utf8))
    }

    public func enqueue(_ response: HTTPResponse) {
        queue.append(response)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        if queue.isEmpty { return defaultResponse }
        return queue.removeFirst()
    }

    /// The most recently received request, for assertions.
    public var lastRequest: HTTPRequest? { requests.last }
}
