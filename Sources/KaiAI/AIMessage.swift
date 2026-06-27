import Foundation

/// The role of a message in a conversation with an AI provider.
public enum AIRole: String, Sendable, Codable, Equatable {
    case system
    case user
    case assistant
}

/// A single message in an AI conversation.
public struct AIMessage: Sendable, Codable, Equatable {
    public let role: AIRole
    public let content: String

    public init(role: AIRole, content: String) {
        self.role = role
        self.content = content
    }

    public static func system(_ content: String) -> AIMessage { .init(role: .system, content: content) }
    public static func user(_ content: String) -> AIMessage { .init(role: .user, content: content) }
    public static func assistant(_ content: String) -> AIMessage { .init(role: .assistant, content: content) }
}

/// Provider-agnostic generation options. Providers map these onto their own
/// parameters and ignore anything they do not support.
public struct AIGenerationOptions: Sendable, Codable, Equatable {
    public var temperature: Double
    public var maxTokens: Int?

    public init(temperature: Double = 0.7, maxTokens: Int? = nil) {
        self.temperature = temperature
        self.maxTokens = maxTokens
    }

    public static let `default` = AIGenerationOptions()
}

/// A completion request: the conversation so far plus generation options.
public struct AIRequest: Sendable, Codable, Equatable {
    public var messages: [AIMessage]
    public var options: AIGenerationOptions

    public init(messages: [AIMessage], options: AIGenerationOptions = .default) {
        self.messages = messages
        self.options = options
    }
}

/// Token accounting reported by a provider, when available.
public struct AIUsage: Sendable, Codable, Equatable {
    public let promptTokens: Int
    public let completionTokens: Int

    public init(promptTokens: Int = 0, completionTokens: Int = 0) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }

    public var totalTokens: Int { promptTokens + completionTokens }
}

/// A completion response from a provider.
public struct AIResponse: Sendable, Codable, Equatable {
    public let content: String
    public let usage: AIUsage

    public init(content: String, usage: AIUsage = AIUsage()) {
        self.content = content
        self.usage = usage
    }
}
