import AVFoundation
import Foundation

@MainActor
final class GameAudioManager {
    static let shared = GameAudioManager()

    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    // MARK: - Public API

    func playLoop(_ name: String, volume: Float = 0.2) {
        let player = cachedPlayer(for: name)
        guard let player, !player.isPlaying else { return }
        player.numberOfLoops = -1
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    func stopLoop(_ name: String) {
        players[name]?.stop()
    }

    func playCatchSound(_ name: String, volume: Float = 0.4) {
        let player = cachedPlayer(for: name)
        guard let player else { return }
        player.numberOfLoops = 0
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    func stopAll() {
        for player in players.values { player.stop() }
    }

    // MARK: - Cached player with procedural synthesis

    private func cachedPlayer(for name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let data = synthesize(name: name),
              let player = try? AVAudioPlayer(data: data) else { return nil }
        player.prepareToPlay()
        players[name] = player
        return player
    }

    // MARK: - Procedural WAV synthesis

    private func synthesize(name: String) -> Data? {
        switch name {
        case "underwater_loop":
            return tone(duration: 2.0, freq: 90, overtone: 180, noise: 0.04, tremolo: 0.3, attack: 0.3, release: 0.3)
        case "bubble_pop":
            return tone(duration: 0.25, freq: 500, overtone: 1000, noise: 0.1, tremolo: 8, attack: 0.01, release: 0.18)
        case "grass_loop":
            return tone(duration: 1.8, freq: 160, overtone: 320, noise: 0.03, tremolo: 10, attack: 0.1, release: 0.2)
        case "tick_catch":
            return tone(duration: 0.15, freq: 280, overtone: 560, noise: 0.08, tremolo: 18, attack: 0.01, release: 0.1)
        case "floor_loop":
            return tone(duration: 1.4, freq: 120, overtone: 240, noise: 0.02, tremolo: 5, attack: 0.08, release: 0.2)
        case "mouse_squeak":
            return tone(duration: 0.18, freq: 1100, overtone: 1600, noise: 0.04, tremolo: 16, attack: 0.01, release: 0.12)
        case "garden_loop":
            return tone(duration: 1.6, freq: 260, overtone: 520, noise: 0.03, tremolo: 12, attack: 0.1, release: 0.18)
        case "ladybug_catch":
            return tone(duration: 0.2, freq: 440, overtone: 800, noise: 0.05, tremolo: 20, attack: 0.01, release: 0.14)
        default:
            return nil
        }
    }

    private func tone(
        duration: Double, freq: Double, overtone: Double,
        noise: Double, tremolo: Double,
        attack: Double, release: Double
    ) -> Data {
        let sampleRate = 22_050
        let count = Int(Double(sampleRate) * duration)

        var pcm = Data(capacity: count * 2)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let env = envelope(t: t, dur: duration, atk: attack, rel: release)
            let sig = sin(2 * .pi * freq * t) * 0.6
                + sin(2 * .pi * overtone * t) * 0.25
                + (noise > 0 ? noise * Double.random(in: -1...1) : 0)
            let trem = tremolo > 0 ? 0.7 + 0.3 * sin(2 * .pi * tremolo * t) : 1.0
            let sample = max(-1, min(1, sig * trem * env))
            let int16 = Int16(sample * Double(Int16.max) * 0.65)
            withUnsafeBytes(of: int16.littleEndian) { pcm.append(contentsOf: $0) }
        }

        return wavHeader(sampleRate: sampleRate, sampleCount: count) + pcm
    }

    private func envelope(t: Double, dur: Double, atk: Double, rel: Double) -> Double {
        let rise = min(1, t / max(atk, 0.001))
        let fall = min(1, (dur - t) / max(rel, 0.001))
        return max(0, min(rise, fall))
    }

    private func wavHeader(sampleRate: Int, sampleCount: Int) -> Data {
        let dataSize = UInt32(sampleCount * 2)
        let riffSize = 36 + dataSize
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append("RIFF".data(using: .ascii)!)
        u32(riffSize)
        d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!)
        u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2))
        u16(2); u16(16)
        d.append("data".data(using: .ascii)!)
        u32(dataSize)
        return d
    }
}
