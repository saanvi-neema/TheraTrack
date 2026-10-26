import AVFoundation

/// Speaks form-feedback aloud. Pre-renders the fixed set of phrases to cached audio
/// files so playback is instant instead of waiting on live speech synthesis.
final class SpeechFeedbackSpeaker: @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var cachedFiles: [String: URL] = [:]

    private static let cacheDirectory: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpeechCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        // .playback (rather than the default ambient category) makes speech audible
        // even if the phone's silent switch is on — this is functional guidance the
        // user needs to hear, not decorative sound that should be silenced with it.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Renders each phrase to a cached audio file if one doesn't already exist on
    /// disk from a previous run, so by the time it's actually needed during a
    /// session, playback is instant instead of waiting on live synthesis.
    func prewarm(phrases: [String]) {
        for phrase in phrases {
            let url = Self.cacheURL(for: phrase)
            if FileManager.default.fileExists(atPath: url.path) {
                cachedFiles[phrase] = url
                continue
            }

            var audioFile: AVAudioFile?
            synthesizer.write(AVSpeechUtterance(string: phrase)) { [weak self] buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }
                guard pcmBuffer.frameLength > 0 else {
                    if audioFile != nil {
                        self?.cachedFiles[phrase] = url
                    }
                    return
                }
                if audioFile == nil {
                    audioFile = try? AVAudioFile(forWriting: url, settings: pcmBuffer.format.settings)
                }
                try? audioFile?.write(from: pcmBuffer)
            }
        }
    }

    func speak(_ message: String) {
        if let url = cachedFiles[message] {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            return
        }
        guard !synthesizer.isSpeaking else { return }
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    private static func cacheURL(for phrase: String) -> URL {
        cacheDirectory.appendingPathComponent("\(abs(phrase.hashValue)).caf")
    }
}
