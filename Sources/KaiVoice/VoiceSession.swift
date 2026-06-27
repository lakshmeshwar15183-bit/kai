import Foundation
import KaiCore

/// Coordinates the voice lifecycle: it stays asleep until it hears the wake
/// phrase, classifies each utterance, and — crucially — honours stop words by
/// halting and returning to sleep. Per Kai's rules, it never keeps listening
/// after being told to stop.
///
/// The classification logic is pure and fully tested; the macOS app drives it
/// with a real recognizer and synthesizer.
public actor VoiceSession {
    public private(set) var state: VoiceState
    private let wakePhrase: String
    private let sleepPhrases: Set<String>
    private let stopController: StopController

    public init(
        wakePhrase: String = "hey kai",
        state: VoiceState = .sleeping,
        stopController: StopController
    ) {
        self.wakePhrase = wakePhrase.lowercased()
        self.state = state
        self.sleepPhrases = ["go to sleep", "sleep", "goodbye", "stop listening"]
        self.stopController = stopController
    }

    /// Classifies a recognised utterance, updating state and the stop controller.
    public func handle(_ utterance: String) async -> VoiceEvent {
        let normalized = utterance.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Stop words always win and return Kai to sleep.
        if let stopWord = StopWord(normalized) {
            await stopController.requestStop(mapToCore(stopWord))
            state = .sleeping
            return .stopped(stopWord)
        }

        switch state {
        case .sleeping:
            if normalized.contains(wakePhrase) {
                await stopController.reset()
                state = .listening
                return .wokeUp
            }
            return .ignoredWhileSleeping

        case .listening, .processing:
            if sleepPhrases.contains(normalized) {
                state = .sleeping
                return .wentToSleep
            }
            state = .processing
            return .command(stripWakePhrase(from: utterance))
        }
    }

    /// Marks the end of command handling, returning to listening if still awake.
    public func finishedProcessing() {
        if state == .processing { state = .listening }
    }

    // MARK: - Helpers

    private func stripWakePhrase(from utterance: String) -> String {
        let trimmed = utterance.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix(wakePhrase) {
            let stripped = String(trimmed.dropFirst(wakePhrase.count))
            return stripped.trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
        }
        return trimmed
    }

    private func mapToCore(_ word: StopWord) -> StopCommand {
        switch word {
        case .stop: return .stop
        case .pause: return .pause
        case .cancel: return .cancel
        case .abort: return .abort
        }
    }
}
