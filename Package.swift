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
        .library(name: "KaiMemory", targets: ["KaiMemory"]),
        .library(name: "KaiAutomation", targets: ["KaiAutomation"]),
        .library(name: "KaiPlugins", targets: ["KaiPlugins"]),
        .library(name: "KaiApp", targets: ["KaiApp"]),
        .executable(name: "kai-cli", targets: ["kai-cli"])
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

        // MARK: macOS-only surface (guarded internally with #if os(macOS))
        .target(
            name: "KaiApp",
            dependencies: ["KaiCore", "KaiAI", "KaiMemory", "KaiAutomation", "KaiPlugins"]
        ),

        // MARK: Linux-runnable demo that wires the core together
        .executableTarget(
            name: "kai-cli",
            dependencies: ["KaiCore", "KaiAI", "KaiMemory", "KaiAutomation", "KaiPlugins"]
        ),

        // MARK: Tests
        .testTarget(name: "KaiCoreTests", dependencies: ["KaiCore"]),
        .testTarget(name: "KaiAITests", dependencies: ["KaiAI"]),
        .testTarget(name: "KaiMemoryTests", dependencies: ["KaiMemory"]),
        .testTarget(name: "KaiAutomationTests", dependencies: ["KaiAutomation", "KaiCore"]),
        .testTarget(name: "KaiPluginsTests", dependencies: ["KaiPlugins"])
    ]
)
