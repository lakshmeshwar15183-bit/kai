import Foundation

/// Shared encode → send → validate → decode pipeline used by every provider.
/// Centralising it keeps each provider focused on its vendor's request/response
/// shape and guarantees uniform error mapping.
enum ProviderHTTP {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        return encoder
    }()

    static let decoder = JSONDecoder()

    static func perform<RequestBody: Encodable, ResponseBody: Decodable>(
        transport: any HTTPTransport,
        url: URL,
        headers: [String: String],
        body: RequestBody,
        decode _: ResponseBody.Type
    ) async throws -> ResponseBody {
        let data: Data
        do {
            data = try encoder.encode(body)
        } catch {
            throw AIProviderError.invalidConfiguration(reason: "could not encode request: \(error)")
        }

        var allHeaders = headers
        if allHeaders["Content-Type"] == nil { allHeaders["Content-Type"] = "application/json" }

        let response = try await transport.send(
            HTTPRequest(url: url, method: "POST", headers: allHeaders, body: data)
        )

        guard response.isSuccess else {
            let message = String(data: response.body, encoding: .utf8) ?? "<no body>"
            throw AIProviderError.httpError(status: response.statusCode, message: message)
        }

        do {
            return try decoder.decode(ResponseBody.self, from: response.body)
        } catch {
            throw AIProviderError.decodingFailed(reason: String(describing: error))
        }
    }
}
