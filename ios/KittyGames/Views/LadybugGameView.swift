import SwiftUI

nonisolated struct LadybugBlueprint: Identifiable, Sendable {
    let id = UUID()
    let size: CGFloat
    let orbitRadiusX: Double
    let orbitRadiusY: Double
    let orbitFreqX: Double
    let orbitFreqY: Double
    let centerX: Double
    let centerY: Double
    let phaseX: Double
    let phaseY: Double
    let wingFreq: Double
}

@Observable
class LadybugViewModel {
    var bugs: [LadybugBlueprint] = []
    var caughtIDs: Set<UUID> = []
    var catchTimes: [UUID: TimeInterval] = [:]
    var catchEffects: [(id: UUID, position: CGPoint, time: TimeInterval)] = []
    var score: Int = 0
    var screenSize: CGSize = .zero
    var currentTime: TimeInterval = 0
    private(set) var startTime: TimeInterval = Date.timeIntervalSinceReferenceDate

    func setup(size: CGSize) {
        screenSize = size
        startTime = Date.timeIntervalSinceReferenceDate
        bugs = (0..<6).map { i in
            LadybugBlueprint(
                size: CGFloat.random(in: 62...85),
                orbitRadiusX: Double.random(in: 80...160),
                orbitRadiusY: Double.random(in: 60...130),
                orbitFreqX: Double.random(in: 0.3...0.65),
                orbitFreqY: Double.random(in: 0.25...0.6),
                centerX: 0.15 * size.width + Double(i % 3) * 0.3 * size.width,
                centerY: 0.2 * size.height + Double(i / 3) * 0.55 * size.height,
                phaseX: Double(i) * 1.26,
                phaseY: Double(i) * 0.94,
                wingFreq: Double.random(in: 3.0...5.0)
            )
        }
    }

    func position(for b: LadybugBlueprint, at time: TimeInterval) -> CGPoint {
        let elapsed = time - startTime
        let margin = 55.0
        let rawX = b.centerX + sin(elapsed * b.orbitFreqX + b.phaseX) * b.orbitRadiusX
        let rawY = b.centerY + cos(elapsed * b.orbitFreqY + b.phaseY) * b.orbitRadiusY
        let x = min(max(rawX, margin), screenSize.width - margin)
        let y = min(max(rawY, margin), screenSize.height - margin)
        return CGPoint(x: x, y: y)
    }

    func wingOpen(for b: LadybugBlueprint, at time: TimeInterval) -> Double {
        let elapsed = time - startTime
        return (sin(elapsed * b.wingFreq) + 1) / 2
    }

    func catchBug(_ id: UUID, position: CGPoint, at time: TimeInterval) {
        guard !caughtIDs.contains(id) else { return }
        caughtIDs.insert(id)
        catchTimes[id] = time
        catchEffects.append((id: UUID(), position: position, time: time))
        score += 1
    }

    func update(at time: TimeInterval) {
        currentTime = time
        let toRespawn = catchTimes.filter { time - $0.value > 1.6 }.map(\.key)
        for id in toRespawn {
            caughtIDs.remove(id)
            catchTimes.removeValue(forKey: id)
        }
        catchEffects = catchEffects.filter { time - $0.time < 0.9 }
    }

    func shiftTimeline(by delta: TimeInterval) {
        startTime += delta
        currentTime += delta
        catchTimes = catchTimes.mapValues { $0 + delta }
        catchEffects = catchEffects.map { effect in
            (id: effect.id, position: effect.position, time: effect.time + delta)
        }
    }

    func handleTap(at point: CGPoint) {
        let time = currentTime
        var bestID: UUID? = nil
        var bestDist = Double.infinity
        for b in bugs where !caughtIDs.contains(b.id) {
            let pos = position(for: b, at: time)
            let dist = hypot(pos.x - point.x, pos.y - point.y)
            let hitRadius = Double(b.size) * 1.05
            if dist < hitRadius && dist < bestDist {
                bestDist = dist
                bestID = b.id
            }
        }
        if let id = bestID, let b = bugs.first(where: { $0.id == id }) {
            let pos = position(for: b, at: time)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            catchBug(id, position: pos, at: time)
        }
    }
}

struct LadybugGameView: View {
    @State private var vm = LadybugViewModel()
    @State private var isPaused: Bool = false
    @State private var pausedTime: TimeInterval = 0
    @State private var pauseStartedAt: TimeInterval? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GardenBackground()
                    .ignoresSafeArea()

                TimelineView(.animation) { _ in
                    let time = isPaused ? pausedTime : vm.currentTime
                    ZStack {
                        ForEach(vm.bugs) { b in
                            let pos = vm.position(for: b, at: time)
                            let wing = vm.wingOpen(for: b, at: time)
                            let caught = vm.caughtIDs.contains(b.id)
                            let catchTime = vm.catchTimes[b.id] ?? time
                            let progress = caught ? min((time - catchTime) / 0.5, 1.0) : 0
                            LadybugView(size: b.size, wingOpen: wing, catchProgress: progress)
                                .position(pos)
                        }
                        ForEach(vm.catchEffects, id: \.id) { effect in
                            let progress = min((time - effect.time) / 0.7, 1.0)
                            LadybugCatchEffect(progress: progress)
                                .position(effect.position)
                        }
                    }
                }

                Color.clear
                    .contentShape(Rectangle())
                    .padding(.top, 132)
                    .padding(.bottom, 128)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !isPaused else { return }
                                vm.handleTap(at: value.location)
                            }
                    )
                    .zIndex(5)

                VStack(spacing: 0) {
                    GameHeaderView(
                        title: "Ladybug",
                        subtitle: "Marienkäfer flattern in unregelmäßigen Schleifen durch den Garten und tauchen nach einem Fang wieder auf.",
                        score: vm.score,
                        scoreColor: Color(hue: 0.0, saturation: 0.75, brightness: 0.75),
                        onExit: { dismiss() }
                    )

                    Spacer()

                    GameControlBar(
                        isPaused: isPaused,
                        onTogglePause: {
                            let now = Date.timeIntervalSinceReferenceDate
                            if isPaused {
                                if let pauseStartedAt {
                                    vm.shiftTimeline(by: now - pauseStartedAt)
                                }
                                pauseStartedAt = nil
                                vm.update(at: now)
                                isPaused = false
                            } else {
                                pausedTime = vm.currentTime
                                pauseStartedAt = now
                                isPaused = true
                            }
                        },
                        onExit: { dismiss() }
                    )
                }
                .zIndex(10)
            }
            .onAppear {
                vm.setup(size: geo.size)
                vm.update(at: Date.timeIntervalSinceReferenceDate)
                GameAudioManager.shared.playLoop("ladybug_loop", volume: 0.15)
            }
            .onDisappear { GameAudioManager.shared.stopLoop("ladybug_loop") }
            .task(id: isPaused) {
                while !Task.isCancelled {
                    if !isPaused {
                        vm.update(at: Date.timeIntervalSinceReferenceDate)
                        GameAudioManager.shared.playThrottled("ladybug_flap", volume: 0.28, minInterval: 0.8)
                    }
                    try? await Task.sleep(for: .milliseconds(16))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct LadybugView: View {
    let size: CGFloat
    let wingOpen: Double
    let catchProgress: Double

    var body: some View {
        ZStack {
            if wingOpen > 0.15 {
                Ellipse()
                    .fill(Color(hue: 0.02, saturation: 0.85, brightness: 0.82).opacity(0.7))
                    .frame(width: size * 0.4 * wingOpen, height: size * 0.55)
                    .offset(x: -size * 0.28)
                    .rotationEffect(.degrees(-15))

                Ellipse()
                    .fill(Color(hue: 0.02, saturation: 0.85, brightness: 0.82).opacity(0.7))
                    .frame(width: size * 0.4 * wingOpen, height: size * 0.55)
                    .offset(x: size * 0.28)
                    .rotationEffect(.degrees(15))
            }

            Ellipse()
                .fill(Color(hue: 0.02, saturation: 0.88, brightness: 0.85))
                .frame(width: size * 0.62, height: size * 0.5)
                .offset(y: size * 0.05)

            Circle()
                .fill(.black)
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: -size * 0.1)

            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: size * 0.12)
                .offset(x: -size * 0.09, y: -size * 0.16)

            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: size * 0.12)
                .offset(x: size * 0.09, y: -size * 0.16)

            Circle()
                .fill(.black)
                .frame(width: size * 0.15)
                .offset(x: -size * 0.14, y: size * 0.06)

            Circle()
                .fill(.black)
                .frame(width: size * 0.12)
                .offset(x: size * 0.16, y: size * 0.02)

            Circle()
                .fill(.black)
                .frame(width: size * 0.1)
                .offset(x: 0, y: size * 0.12)

            Capsule()
                .fill(.black)
                .frame(width: size * 0.04, height: size * 0.62)
                .offset(y: size * 0.08)
        }
        .frame(width: size, height: size)
        .scaleEffect(1.0 + catchProgress * 0.6)
        .opacity(1.0 - catchProgress)
        .rotationEffect(.degrees(catchProgress * 300))
        .allowsHitTesting(false)
    }
}

struct LadybugCatchEffect: View {
    let progress: Double

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                let angle = Double(i) * .pi * 2 / 7
                Circle()
                    .fill(Color(hue: Double(i) / 7.0, saturation: 0.9, brightness: 0.95))
                    .frame(width: max(1, 12 - progress * 9))
                    .offset(
                        x: progress * 58 * cos(angle),
                        y: progress * 58 * sin(angle)
                    )
                    .opacity(1.0 - progress)
            }
            Image(systemName: "heart.fill")
                .font(.system(size: max(1, 28 * (1 - progress))))
                .foregroundStyle(Color(hue: 0.95, saturation: 0.8, brightness: 0.9))
                .opacity(progress < 0.5 ? 1 : 1 - (progress - 0.5) / 0.5)
        }
        .allowsHitTesting(false)
    }
}

struct GardenBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.56, saturation: 0.45, brightness: 0.88),
                    Color(hue: 0.52, saturation: 0.55, brightness: 0.7),
                    Color(hue: 0.34, saturation: 0.68, brightness: 0.52)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ForEach(0..<6, id: \.self) { i in
                Ellipse()
                    .fill(Color(hue: 0.33, saturation: 0.6, brightness: 0.55).opacity(0.35))
                    .frame(
                        width: CGFloat(80 + i * 30),
                        height: CGFloat(50 + i * 15)
                    )
                    .offset(
                        x: CGFloat([-100, 60, 150, -50, 120, -140][i % 6]),
                        y: CGFloat([200, 280, 150, 350, 310, 260][i % 6])
                    )
                    .scaleEffect(animate ? 1.05 : 0.97)
                    .animation(
                        .easeInOut(duration: 2.5 + Double(i) * 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.3),
                        value: animate
                    )
            }

            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<22, id: \.self) { i in
                        let h = CGFloat(30 + (i % 4) * 15)
                        Capsule()
                            .fill(Color(hue: 0.33, saturation: 0.78, brightness: 0.48).opacity(0.9))
                            .frame(width: 15, height: h)
                            .rotationEffect(.degrees(animate ? Double(i % 3 - 1) * 6 : Double(i % 3 - 1) * -4), anchor: .bottom)
                            .animation(
                                .easeInOut(duration: 1.8 + Double(i % 4) * 0.35)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.07),
                                value: animate
                            )
                    }
                }
                .frame(height: 75, alignment: .bottom)
                .clipped()
            }

            ForEach(0..<5, id: \.self) { i in
                let symbols = ["suit.heart.fill", "star.fill", "sun.max.fill", "leaf.fill", "drop.fill"]
                let hues: [Double] = [0.95, 0.13, 0.13, 0.33, 0.56]
                let xs: [CGFloat] = [60, 160, 270, 100, 320]
                let ys: [CGFloat] = [650, 700, 640, 750, 680]
                Image(systemName: symbols[i])
                    .font(.system(size: CGFloat(22 + i * 4)))
                    .foregroundStyle(Color(hue: hues[i], saturation: 0.8, brightness: 0.85).opacity(0.7))
                    .position(x: xs[i], y: ys[i])
                    .scaleEffect(animate ? 1.1 : 0.95)
                    .animation(
                        .easeInOut(duration: 2.0 + Double(i) * 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.2),
                        value: animate
                    )
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
