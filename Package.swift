// swift-tools-version: 6.0
import PackageDescription

// Kai – Personal AI Operating System for macOS
//
// The package is split into platform-agnostic libraries (which build and test
// on any Swift platform, including Linux/CI) and macOS-only surfaces (UI and
// OS-specific skills) that are guarded with `#if os(macOS)`.
//
// Dependency direction is strictly downward to avoid cycles:
//   KaiCore  ->  {KaiAI, KaiMemory, KaiAutomation}  ->  KaiPlugins  ->  {KaiApp, kai-cli}

let package = Package(
    name: "Kai",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "KaiCore", targets: ["KaiCore"]),
        .library(name: "KaiAI", targets: ["KaiAI"]),
        .library(name: "KaiAIProviders", targets: ["KaiAIProviders"]),
        .library(name: "KaiMemory", targets: ["KaiMemory"]),
        .library(name: "KaiAutomation", targets: ["KaiAutomation"]),
        .library(name: "KaiPlugins", targets: ["KaiPlugins"]),
        .library(name: "KaiBrowser", targets: ["KaiBrowser"]),
        .library(name: "KaiFinder", targets: ["KaiFinder"]),
        .library(name: "KaiVision", targets: ["KaiVision"]),
        .library(name: "KaiVoice", targets: ["KaiVoice"]),
        .library(name: "KaiApp", targets: ["KaiApp"]),
        .executable(name: "kai-cli", targets: ["kai-cli"]),
        .executable(name: "kai-app", targets: ["kai-app"])
    ],
    targets: [
        // MARK: Platform-agnostic libraries
        .target(
            name: "KaiCore"
        ),
        .target(
            name: "KaiAI",
            dependencies: ["KaiCore"]
        ),
        .target(
            name: "KaiAIProviders",
            dependencies: ["KaiAI"]
        ),
        .target(
            name: "KaiMemory",
            dependencies: ["KaiCore"]
        ),
        .target(
            name: "KaiAutomation",
            dependencies: ["KaiCore"]
        ),
        .target(
            name: "KaiPlugins",
            dependencies: ["KaiCore", "KaiAI", "KaiMemory", "KaiAutomation"]
        ),

        // MARK: Skills (capabilities delivered as plugins in their own modules)
        .target(
            name: "KaiBrowser",
            dependencies: ["KaiCore", "KaiAI", "KaiPlugins"]
        ),
        .target(
            name: "KaiFinder",
            dependencies: ["KaiCore", "KaiPlugins"]
        ),
        .target(
            name: "KaiVision",
            dependencies: ["KaiCore", "KaiAI", "KaiPlugins"]
        ),
        .target(
            name: "KaiVoice",
            dependencies: ["KaiCore"]
        ),

        // MARK: macOS-only surface (guarded internally with #if os(macOS))
        .target(
            name: "KaiApp",
            dependencies: [
                "KaiCore", "KaiAI", "KaiAIProviders", "KaiMemory", "KaiAutomation",
                "KaiPlugins", "KaiBrowser", "KaiFinder", "KaiVision", "KaiVoice"
            ]
        ),

        // MARK: Executables
        .executableTarget(
            name: "kai-cli",
            dependencies: [
                "KaiCore", "KaiAI", "KaiAIProviders", "KaiMemory", "KaiAutomation",
                "KaiPlugins", "KaiBrowser", "KaiFinder"
            ]
        ),
        // The launchable macOS application entry point (guarded @main).
        .executableTarget(
            name: "kai-app",
            dependencies: ["KaiApp"]
        ),

        // MARK: Tests
        .testTarget(name: "KaiCoreTests", dependencies: ["KaiCore"]),
        .testTarget(name: "KaiAITests", dependencies: ["KaiAI"]),
        .testTarget(name: "KaiAIProvidersTests", dependencies: ["KaiAIProviders", "KaiAI"]),
        .testTarget(name: "KaiMemoryTests", dependencies: ["KaiMemory"]),
        .testTarget(name: "KaiAutomationTests", dependencies: ["KaiAutomation", "KaiCore"]),
        .testTarget(name: "KaiPluginsTests", dependencies: ["KaiPlugins"]),
        .testTarget(name: "KaiBrowserTests", dependencies: ["KaiBrowser", "KaiPlugins", "KaiAI", "KaiMemory", "KaiCore"]),
        .testTarget(name: "KaiFinderTests", dependencies: ["KaiFinder", "KaiPlugins", "KaiCore"]),
        .testTarget(name: "KaiVisionTests", dependencies: ["KaiVision", "KaiPlugins", "KaiCore"]),
        .testTarget(name: "KaiVoiceTests", dependencies: ["KaiVoice", "KaiCore"])
    ]
)
