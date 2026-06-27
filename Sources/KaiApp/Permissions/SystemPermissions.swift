#if os(macOS)
import Foundation
import AppKit
import AVFoundation
import Speech
import CoreGraphics
import ApplicationServices

/// The macOS system permissions Kai needs for its various skills. Kai requests
/// these explicitly during onboarding and surfaces their status in the
/// Permission Manager; it never works around a denied permission.
public enum SystemPermission: String, CaseIterable, Sendable, Identifiable {
    case accessibility       // control other apps / read UI (AX)
    case screenRecording     // ScreenCaptureKit for screen understanding
    case microphone          // voice input
    case speechRecognition   // transcription

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .screenRecording: return "Screen Recording"
        case .microphone: return "Microphone"
        case .speechRecognition: return "Speech Recognition"
        }
    }

    public var rationale: String {
        switch self {
        case .accessibility: return "Lets Kai operate apps and read on-screen controls (Execute mode)."
        case .screenRecording: return "Lets Kai understand what's on your screen (Observe mode)."
        case .microphone: return "Lets Kai hear voice commands."
        case .speechRecognition: return "Lets Kai transcribe your speech."
        }
    }
}

/// The authorisation state of a permission.
public enum PermissionAuthorization: String, Sendable {
    case notDetermined, denied, authorized
}

/// Reads and requests macOS permission states. All checks are read-only and
/// safe to call repeatedly; requests route through the standard system prompts.
public struct SystemPermissionService: Sendable {
    public init() {}

    public func status(of permission: SystemPermission) -> PermissionAuthorization {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted() ? .authorized : .notDetermined
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .authorized : .notDetermined
        case .microphone:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: return .authorized
            case .denied, .restricted: return .denied
            default: return .notDetermined
            }
        case .speechRecognition:
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: return .authorized
            case .denied, .restricted: return .denied
            default: return .notDetermined
            }
        }
    }

    /// Requests a permission via the system prompt. Returns the resulting status.
    @discardableResult
    public func request(_ permission: SystemPermission) async -> PermissionAuthorization {
        switch permission {
        case .accessibility:
            // Triggers the system prompt to add Kai to Accessibility. The option
            // key is referenced by its documented string value to avoid SDK
            // symbol-import differences across toolchains.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            return status(of: .accessibility)
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
            return status(of: .screenRecording)
        case .microphone:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .authorized : .denied
        case .speechRecognition:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { auth in
                    continuation.resume(returning: auth == .authorized ? .authorized : (auth == .notDetermined ? .notDetermined : .denied))
                }
            }
        }
    }

    /// Opens System Settings at the relevant privacy pane.
    public func openSettings(for permission: SystemPermission) {
        let anchor: String
        switch permission {
        case .accessibility: anchor = "Privacy_Accessibility"
        case .screenRecording: anchor = "Privacy_ScreenCapture"
        case .microphone: anchor = "Privacy_Microphone"
        case .speechRecognition: anchor = "Privacy_SpeechRecognition"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
#endif
