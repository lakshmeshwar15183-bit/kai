import Foundation

/// A minimal, provider-agnostic HTTP request. Providers build one of these and
/// hand it to an ``HTTPTransport``; they never touch URLSession directly, which
/// keeps them deterministically testable.
public struct HTTPRequest: Sendable, Equatable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?

    public init(url: URL, method: String = "POST", headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

/// The response returned by an ``HTTPTransport``.
public struct HTTPResponse: Sendable, Equatable {
    public var statusCode: Int
    public var body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    /// Whether the status code is in the 2xx success range.
    public var isSuccess: Bool { (200..<300).contains(statusCode) }
}

/// The seam between providers and the network. The production implementation is
/// ``URLSessionTransport``; tests use a mock. Being a protocol lets every
/// provider be exercised without real network access.
public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}
