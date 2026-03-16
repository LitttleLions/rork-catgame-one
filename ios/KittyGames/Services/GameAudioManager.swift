import AVFoundation
import Foundation

@MainActor
final class GameAudioManager {
    static let shared = GameAudioManager()

    private struct SoundRecipe {
        struct Partial {
            let frequency: Double
            let amplitude: Double
        }

        let duration: Double
        let partials: [Partial]
        let noiseAmount: Double
        let tremoloFrequency: Double
        let attack: Double
        let release: Double
    }

    private var players: [String: AVAudioPlayer] = [:]
    private var throttleTimes: [String: TimeInterval] = [:]

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func playLoop(_ resource: String, volume: Float = 0.25) {
        guard let player = loadPlayer(resource: resource) else { return }
        player.numberOfLoops = -1
        player.volume = volume
        guard !player.isPlaying else { return }
        player.currentTime = 0
        player.play()
    }

    func stopLoop(_ resource: String) {
        players[resource]?.stop()
        players[resource]?.currentTime = 0
    }

    func playThrottled(_ resource: String, volume: Float = 0.5, minInterval: TimeInterval) {
        let now = Date.timeIntervalSinceReferenceDate
        if let last = throttleTimes[resource], now - last < minInterval {
            return
        }
        throttleTimes[resource] = now
        playOneShot(resource, volume: volume)
    }

    func playOneShot(_ resource: String, volume: Float = 0.5) {
        guard let player = loadPlayer(resource: resource) else { return }
        player.numberOfLoops = 0
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    private func loadPlayer(resource: String) -> AVAudioPlayer? {
        if let existing = players[resource] {
            return existing
        }

        if let bundleURL = ["mp3", "m4a", "wav"]
            .compactMap({ Bundle.main.url(forResource: resource, withExtension: $0) })
            .first,
           let bundlePlayer = try? AVAudioPlayer(contentsOf: bundleURL)
        {
            bundlePlayer.prepareToPlay()
            players[resource] = bundlePlayer
            return bundlePlayer
        }

        guard let recipe = recipe(for: resource),
              let data = renderWaveData(recipe: recipe),
              let generatedPlayer = try? AVAudioPlayer(data: data)
        else {
            return nil
        }

        generatedPlayer.prepareToPlay()
        players[resource] = generatedPlayer
        return generatedPlayer
    }

    private func recipe(for resource: String) -> SoundRecipe? {
        switch resource {
        case "underwater_loop":
            return SoundRecipe(
                duration: 2.6,
                partials: [.init(frequency: 96, amplitude: 0.34), .init(frequency: 192, amplitude: 0.16)],
                noiseAmount: 0.035,
                tremoloFrequency: 0.35,
                attack: 0.25,
                release: 0.35
            )
        case "bubble_pop":
            return SoundRecipe(
                duration: 0.35,
                partials: [.init(frequency: 420, amplitude: 0.28), .init(frequency: 860, amplitude: 0.14)],
                noiseAmount: 0.08,
                tremoloFrequency: 7,
                attack: 0.02,
                release: 0.25
            )
        case "tick_loop":
            return SoundRecipe(
                duration: 1.6,
                partials: [.init(frequency: 170, amplitude: 0.18), .init(frequency: 340, amplitude: 0.1)],
                noiseAmount: 0.025,
                tremoloFrequency: 12,
                attack: 0.08,
                release: 0.2
            )
        case "tick_step":
            return SoundRecipe(
                duration: 0.18,
                partials: [.init(frequency: 250, amplitude: 0.24), .init(frequency: 510, amplitude: 0.1)],
                noiseAmount: 0.07,
                tremoloFrequency: 20,
                attack: 0.01,
                release: 0.12
            )
        case "mouse_loop":
            return SoundRecipe(
                duration: 1.5,
                partials: [.init(frequency: 650, amplitude: 0.11), .init(frequency: 980, amplitude: 0.09)],
                noiseAmount: 0.02,
                tremoloFrequency: 6,
                attack: 0.07,
                release: 0.2
            )
        case "mouse_squeak":
            return SoundRecipe(
                duration: 0.2,
                partials: [.init(frequency: 1200, amplitude: 0.25), .init(frequency: 1650, amplitude: 0.1)],
                noiseAmount: 0.03,
                tremoloFrequency: 18,
                attack: 0.01,
                release: 0.15
            )
        case "ladybug_loop":
            return SoundRecipe(
                duration: 1.7,
                partials: [.init(frequency: 290, amplitude: 0.12), .init(frequency: 580, amplitude: 0.08)],
                noiseAmount: 0.03,
                tremoloFrequency: 15,
                attack: 0.08,
                release: 0.18
            )
        case "ladybug_flap":
            return SoundRecipe(
                duration: 0.2,
                partials: [.init(frequency: 420, amplitude: 0.18), .init(frequency: 770, amplitude: 0.1)],
                noiseAmount: 0.05,
                tremoloFrequency: 22,
                attack: 0.01,
                release: 0.14
            )
        default:
            return nil
        }
    }

    private func renderWaveData(recipe: SoundRecipe) -> Data? {
        let sampleRate = 22_050
        let sampleCount = Int(Double(sampleRate) * recipe.duration)
        guard sampleCount > 0 else { return nil }

        var pcmData = Data(capacity: sampleCount * 2)

        for index in 0..<sampleCount {
            let time = Double(index) / Double(sampleRate)
            let startRamp = min(1.0, time / max(recipe.attack, 0.0001))
            let endTime = recipe.duration - time
            let endRamp = min(1.0, endTime / max(recipe.release, 0.0001))
            let envelope = max(0.0, min(startRamp, endRamp))

            let tonal = recipe.partials.reduce(0.0) { sum, partial in
                sum + partial.amplitude * sin(2 * .pi * partial.frequency * time)
            }

            let tremolo = recipe.tremoloFrequency > 0
                ? 0.65 + 0.35 * sin(2 * .pi * recipe.tremoloFrequency * time)
                : 1.0

            let noise = recipe.noiseAmount > 0
                ? recipe.noiseAmount * Double.random(in: -1...1)
                : 0

            let sample = max(-1.0, min(1.0, (tonal * tremolo + noise) * envelope))
            let intSample = Int16(sample * Double(Int16.max) * 0.7)
            pcmData.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian, Array.init))
        }

        return waveHeader(sampleRate: sampleRate, sampleCount: sampleCount) + pcmData
    }

    private func waveHeader(sampleRate: Int, sampleCount: Int) -> Data {
        let bitsPerSample: UInt16 = 16
        let channelCount: UInt16 = 1
        let bytesPerSample = Int(bitsPerSample / 8)
        let byteRate = UInt32(sampleRate * Int(channelCount) * bytesPerSample)
        let blockAlign = UInt16(Int(channelCount) * bytesPerSample)
        let dataSize = UInt32(sampleCount * Int(channelCount) * bytesPerSample)
        let riffSize = UInt32(36) + dataSize

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: riffSize.littleEndian, Array.init))
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: channelCount.littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian, Array.init))
        data.append("data".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian, Array.init))
        return data
    }
}
