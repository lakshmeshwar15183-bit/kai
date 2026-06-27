import Foundation

/// The voice subsystem's listening state.
public enum VoiceState: String, Sendable, Equatable {
    /// Not listening for commands; only the wake phrase can wake Kai.
    case sleeping
    /// Actively listening for a command.
    case listening
    /// Handling a recognised command.
    case processing
}

/// The outcome of classifying a recognised utterance.
public enum VoiceEvent: Sendable, Equatable {
    /// The wake phrase was heard while sleeping.
    case wokeUp
    /// Speech heard while sleeping that was not the wake phrase — ignored.
    case ignoredWhileSleeping
    /// A stop word (stop/pause/cancel/abort) was heard; Kai halts and sleeps.
    case stopped(StopWord)
    /// A "go to sleep" style command returned Kai to sleep.
    case wentToSleep
    /// A command to route to the rest of Kai.
    case command(String)
}

/// The recognised stop words. Mirrors `KaiCore.StopCommand` but lives here to
/// keep the voice models self-contained; the session maps it onto the core stop
/// controller.
public enum StopWord: String, Sendable, CaseIterable, Equatable {
    case stop, pause, cancel, abort

    public init?(_ utterance: String) {
        let normalized = utterance.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let value = StopWord(rawValue: normalized) else { return nil }
        self = value
    }
}

/// Errors from the speech engines.
public enum VoiceError: Error, Sendable, Equatable, CustomStringConvertible {
    case recognizerUnavailable
    case permissionDenied
    case recognitionFailed(reason: String)

    public var description: String {
        switch self {
        case .recognizerUnavailable: return "Speech recognizer unavailable."
        case .permissionDenied: return "Microphone/speech permission denied."
        case let .recognitionFailed(reason): return "Recognition failed: \(reason)."
        }
    }
}
