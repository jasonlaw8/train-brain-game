import AVFoundation

/// Synthesises audio tones programmatically — no bundled audio files.
/// Uses a small pool of pre-attached AVAudioPlayerNodes for low-latency playback.
@MainActor
final class SoundEngine {
    static let shared = SoundEngine()
    private init() { setup() }

    private let engine      = AVAudioEngine()
    private var pool:  [AVAudioPlayerNode] = []
    private var cursor = 0
    private let poolSize   = 6
    private let sampleRate: Double = 44100
    private var ready = false

    // MARK: - Setup

    private func setup() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default,
                                                            options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        let fmt = monoFormat
        for _ in 0..<poolSize {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: fmt)
            pool.append(node)
        }
        do {
            try engine.start()
            ready = true
        } catch {}
    }

    private var monoFormat: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    // MARK: - Buffer Generation

    private func makeBuffer(frequency: Double,
                            duration: Double,
                            amplitude: Float = 0.40,
                            overtone: Double = 0) -> AVAudioPCMBuffer? {
        let fmt   = monoFormat
        let count = AVAudioFrameCount(sampleRate * duration)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: count) else { return nil }
        buf.frameLength = count
        guard let ch = buf.floatChannelData?[0] else { return nil }

        let fadeIn  = max(1, Int(sampleRate * 0.008))   // 8 ms attack
        let fadeOut = max(1, Int(sampleRate * 0.025))   // 25 ms release
        let total   = Int(count)

        for i in 0..<total {
            let t = Double(i) / sampleRate
            var env: Float
            if i < fadeIn {
                env = Float(i) / Float(fadeIn)
            } else if i > total - fadeOut {
                env = Float(total - i) / Float(fadeOut)
            } else {
                env = 1.0
            }
            var sample = sin(2 * Double.pi * frequency * t)
            if overtone > 0 {
                sample += 0.25 * sin(2 * Double.pi * frequency * overtone * t)
            }
            ch[i] = Float(sample) * amplitude * env
        }
        return buf
    }

    // MARK: - Playback

    private func next() -> AVAudioPlayerNode {
        let n = pool[cursor % poolSize]
        cursor = (cursor + 1) % poolSize
        return n
    }

    func playTone(frequency: Double, duration: Double = 0.12,
                  amplitude: Float = 0.38, overtone: Double = 0) {
        guard ready else { return }
        guard let buf = makeBuffer(frequency: frequency, duration: duration,
                                   amplitude: amplitude, overtone: overtone) else { return }
        let node = next()
        node.stop()
        node.scheduleBuffer(buf, completionHandler: nil)
        node.play()
    }

    // Schedule a tone after a delay (non-blocking)
    private func delayed(_ delay: Double, _ block: @escaping () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            block()
        }
    }

    // MARK: - Named Sounds

    /// Correct answer — pitch rises slightly with consecutive streak count.
    func playCorrect(streak: Int = 0) {
        let boost = 1.0 + Double(min(streak, 5)) * 0.05
        playTone(frequency: 880.0 * boost, duration: 0.10, amplitude: 0.34)
    }

    /// Wrong answer — soft low bonk.
    func playWrong() {
        playTone(frequency: 220.0, duration: 0.18, amplitude: 0.22, overtone: 1.5)
    }

    /// Short high tick — used for countdown / transition cues.
    func playTick() {
        playTone(frequency: 1046.5, duration: 0.06, amplitude: 0.28)
    }

    /// Rising triad — new personal best.
    func playNewBest() {
        playTone(frequency: 523.25, duration: 0.12, amplitude: 0.40)
        delayed(0.12) { self.playTone(frequency: 659.25, duration: 0.12, amplitude: 0.40) }
        delayed(0.24) { self.playTone(frequency: 783.99, duration: 0.28, amplitude: 0.40) }
    }

    /// Two-note rise — level up.
    func playLevelUp() {
        playTone(frequency: 523.25, duration: 0.10, amplitude: 0.36)
        delayed(0.12) { self.playTone(frequency: 659.25, duration: 0.22, amplitude: 0.36) }
    }

    /// High sparkle — streak milestone.
    func playStreakMilestone() {
        playTone(frequency: 1046.5, duration: 0.08, amplitude: 0.28)
    }

    /// Ascending 4-note unlock — Vault Cracker vault open.
    func playVaultOpen() {
        let notes: [Double] = [392, 494, 587, 784]
        for (i, f) in notes.enumerated() {
            delayed(Double(i) * 0.09) { self.playTone(frequency: f, duration: 0.12) }
        }
    }

    /// Quick success chord (two notes).
    func playSuccess() {
        playTone(frequency: 659.25, duration: 0.10)
        delayed(0.11) { self.playTone(frequency: 783.99, duration: 0.22) }
    }

    /// Cascade of all 9 pentatonic tones — Echo Grid round complete.
    func playMelodyCascade(tileCount: Int = 9) {
        for i in 0..<min(tileCount, SoundEngine.pentatonic.count) {
            let freq = SoundEngine.pentatonic[i]
            delayed(Double(i) * 0.05) { self.playTone(frequency: freq, duration: 0.14) }
        }
    }

    // MARK: - Scale Constants

    /// Pentatonic scale (C4–G5, 9 tones) — Echo Grid tile tones.
    static let pentatonic: [Double] = [261.63, 293.66, 329.63, 392.00, 440.00,
                                        523.25, 587.33, 659.25, 783.99]

    /// Chromatic digit tones (C4–E5, 10 tones) — Vault Cracker digit encoding.
    static let digitTones: [Double] = [261.63, 293.66, 329.63, 349.23, 392.00,
                                        440.00, 493.88, 523.25, 587.33, 659.25]
}
