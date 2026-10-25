import AVFoundation

/// Speaks form-feedback messages aloud, so feedback doesn't rely on reading small
/// text from several feet away (needed to frame a full body in the camera).
final class SpeechFeedbackSpeaker {
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        // .playback (rather than the default ambient category) makes speech audible
        // even if the phone's silent switch is on — this is functional guidance the
        // user needs to hear, not decorative sound that should be silenced with it.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func speak(_ message: String) {
        guard !synthesizer.isSpeaking else { return }
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }
}
