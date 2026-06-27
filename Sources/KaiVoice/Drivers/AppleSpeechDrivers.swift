#if os(macOS)
import Foundation
import Speech
import AVFoundation

/// macOS speech recognition via the Speech framework and `AVAudioEngine`.
/// Captures one utterance per call, stopping at the first final result.
///
/// Requires Microphone and Speech Recognition permission, requested during the
/// app's onboarding flow.
public final class AppleSpeechRecognizer: SpeechRecognizer, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()

    public init(locale: Locale = Locale(identifier: "en-US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    public func transcribeUtterance() async throws -> String {
        guard let recognizer, recognizer.isAvailable else { throw VoiceError.recognizerUnavailable }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        try audioEngine.start()

        defer {
            audioEngine.stop()
            inputNode.removeTap(onBus: 0)
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error, !resumed {
                    resumed = true
                    continuation.resume(throwing: VoiceError.recognitionFailed(reason: error.localizedDescription))
                    return
                }
                if let result, result.isFinal, !resumed {
                    resumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}

/// macOS text-to-speech via `AVSpeechSynthesizer`.
public final class AppleSpeechSynthesizer: SpeechSynthesizer, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func speak(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
#endif
