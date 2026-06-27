import Foundation

/// Transcribes a single spoken utterance. macOS uses the Speech framework
/// (`SFSpeechRecognizer`) with `AVAudioEngine`; tests inject a stub.
public protocol SpeechRecognizer: Sendable {
    func transcribeUtterance() async throws -> String
}

/// Speaks text aloud. macOS uses `AVSpeechSynthesizer`; tests inject a stub.
public protocol SpeechSynthesizer: Sendable {
    func speak(_ text: String) async
}

/// A recognizer that returns scripted utterances in order — for tests and the
/// CLI, where no microphone exists.
public actor ScriptedSpeechRecognizer: SpeechRecognizer {
    private var queue: [String]
    public init(_ utterances: [String]) { self.queue = utterances }
    public func transcribeUtterance() async throws -> String {
        guard !queue.isEmpty else { throw VoiceError.recognitionFailed(reason: "no more scripted input") }
        return queue.removeFirst()
    }
}

/// A synthesizer that records what would have been spoken.
public actor RecordingSpeechSynthesizer: SpeechSynthesizer {
    public private(set) var spoken: [String] = []
    public init() {}
    public func speak(_ text: String) async { spoken.append(text) }
}
