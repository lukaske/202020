import AppKit

/// Small tone synthesiser. Rather than depending on whichever system sounds
/// happen to be installed, the two signals are generated as WAV data in memory
/// so they always sound the same: a soft falling pair when the break starts,
/// a brighter rising phrase when it is time to look back at the screen.
enum Chime {

    private struct Note {
        let frequency: Double
        let start: Double      // seconds from the beginning of the phrase
        let duration: Double
        let gain: Double
    }

    /// Held on to while playing — NSSound stops if it is deallocated.
    private static var playing: [NSSound] = []

    static let lookAway = makeSound(notes: [
        Note(frequency: 784.0, start: 0.00, duration: 0.70, gain: 0.35),   // G5
        Note(frequency: 523.3, start: 0.16, duration: 0.90, gain: 0.40),   // C5
    ])

    static let lookBack = makeSound(notes: [
        Note(frequency: 523.3, start: 0.00, duration: 0.45, gain: 0.38),   // C5
        Note(frequency: 659.3, start: 0.13, duration: 0.45, gain: 0.38),   // E5
        Note(frequency: 987.8, start: 0.26, duration: 1.00, gain: 0.50),   // B5
    ])

    static func playLookAway() { play(lookAway) }
    static func playLookBack() { play(lookBack) }

    private static func play(_ sound: NSSound?) {
        guard Preferences.shared.soundEnabled, let template = sound else { return }
        // Copy so overlapping playback never fights over one instance.
        guard let instance = template.copy() as? NSSound else { return }
        // Squaring the slider position tracks perceived loudness far better than
        // feeding the position straight in as an amplitude.
        let position = Preferences.shared.soundVolume
        instance.volume = Float(position * position)
        playing.append(instance)
        instance.play()
        let lifetime = max(1.0, instance.duration + 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + lifetime) {
            playing.removeAll { $0 === instance }
        }
    }

    // MARK: - Synthesis

    private static let sampleRate = 44_100.0

    private static func makeSound(notes: [Note]) -> NSSound? {
        let length = notes.map { $0.start + $0.duration }.max() ?? 0
        let frameCount = Int(length * sampleRate)
        guard frameCount > 0 else { return nil }

        var samples = [Double](repeating: 0, count: frameCount)
        for note in notes {
            let first = Int(note.start * sampleRate)
            let count = Int(note.duration * sampleRate)
            for i in 0..<count where first + i < frameCount {
                let t = Double(i) / sampleRate
                // Percussive bell: fast attack, exponential decay, one quiet
                // octave partial to keep it from sounding like a test tone.
                let attack = min(1.0, t / 0.006)
                let decay = exp(-t * 4.2)
                let fundamental = sin(2 * .pi * note.frequency * t)
                let partial = 0.22 * sin(2 * .pi * note.frequency * 2 * t)
                samples[first + i] += note.gain * attack * decay * (fundamental + partial)
            }
        }

        // Gentle fade at the very end so the buffer never clicks off.
        let fade = min(frameCount, Int(0.02 * sampleRate))
        for i in 0..<fade {
            samples[frameCount - fade + i] *= 1 - Double(i) / Double(fade)
        }

        return NSSound(data: wavData(from: samples))
    }

    /// 16-bit mono PCM in a WAV container.
    private static func wavData(from samples: [Double]) -> Data {
        let bytesPerSample = 2
        let dataSize = samples.count * bytesPerSample
        var data = Data(capacity: 44 + dataSize)

        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append(u32 value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append(u16 value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF")
        append(u32: UInt32(36 + dataSize))
        append("WAVE")
        append("fmt ")
        append(u32: 16)                                   // PCM header size
        append(u16: 1)                                    // PCM
        append(u16: 1)                                    // mono
        append(u32: UInt32(sampleRate))
        append(u32: UInt32(sampleRate) * UInt32(bytesPerSample))
        append(u16: UInt16(bytesPerSample))
        append(u16: 16)                                   // bits per sample
        append("data")
        append(u32: UInt32(dataSize))

        for sample in samples {
            let clipped = max(-1.0, min(1.0, sample))
            append(u16: UInt16(bitPattern: Int16(clipped * 32_000)))
        }
        return data
    }
}
