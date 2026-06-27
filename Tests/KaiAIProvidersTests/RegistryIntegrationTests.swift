import XCTest
@testable import KaiAIProviders
import KaiAI

/// Verifies the providers integrate with the existing `AIProviderRegistry` seam:
/// a config selects a provider, and switching providers is configuration-only.
final class RegistryIntegrationTests: XCTestCase {
    func testBootstrapRegistersAllDefaults() async {
        let registry = AIProviderRegistry()
        let transport = MockTransport(json: "{}")
        await ProviderBootstrap.registerDefaults(
            into: registry,
            transport: transport,
            resolver: StaticSecretResolver([:])
        )
        let ids = await registry.registeredIDs
        XCTAssertEqual(Set(ids), ["openai", "anthropic", "gemini", "ollama"])
    }

    func testRegistryBuildsEachProviderFromConfig() async throws {
        let registry = AIProviderRegistry()
        let transport = MockTransport(json: "{}")
        await ProviderBootstrap.registerDefaults(
            into: registry, transport: transport, resolver: StaticSecretResolver([:])
        )

        for (providerID, expectedModel) in [("openai", "gpt-4o"), ("anthropic", "claude"), ("gemini", "gemini-1.5"), ("ollama", "llama3")] {
            let provider = try await registry.makeProvider(
                config: AIProviderConfig(providerID: providerID, model: expectedModel)
            )
            XCTAssertEqual(provider.id, providerID)
            XCTAssertEqual(provider.model, expectedModel)
        }
    }

    func testSwitchingProviderIsConfigOnly() async throws {
        // The same registry + transport produce different providers purely from
        // the config's providerID — no code change required to switch vendor.
        let registry = AIProviderRegistry()
        await ProviderBootstrap.registerDefaults(
            into: registry, transport: MockTransport(json: "{}"), resolver: StaticSecretResolver([:])
        )
        let a = try await registry.makeProvider(config: AIProviderConfig(providerID: "openai", model: "m"))
        let b = try await registry.makeProvider(config: AIProviderConfig(providerID: "ollama", model: "m"))
        XCTAssertNotEqual(a.id, b.id)
    }
}
