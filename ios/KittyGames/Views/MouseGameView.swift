import SwiftUI

nonisolated struct MouseBlueprint: Identifiable, Sendable {
    let id = UUID()
    let size: CGFloat
    let speedX: Double
    let speedY: Double
    let phaseX: Double
    let phaseY: Double
    let freqX: Double
    let freqY: Double
    let startX: Double
    let startY: Double
}

@Observable
class MouseViewModel {
    var mice: [MouseBlueprint] = []
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
        var built: [MouseBlueprint] = []
        for i in 0..<4 {
            let sx: Double = Double.random(in: 80...150) * (i % 2 == 0 ? 1.0 : -1.0)
            let sy: Double = Double.random(in: 60...110) * (i % 3 == 0 ? 1.0 : -1.0)
            let ox: Double = 0.2 * Double(size.width) + Double(i) * 0.18 * Double(size.width)
            let oy: Double = 0.2 * Double(size.height) + Double(i % 2) * 0.5 * Double(size.height)
            built.append(MouseBlueprint(
                size: CGFloat.random(in: 70...90),
                speedX: sx,
                speedY: sy,
                phaseX: Double(i) * 1.57,
                phaseY: Double(i) * 1.05,
                freqX: Double.random(in: 0.35...0.7),
                freqY: Double.random(in: 0.4...0.8),
                startX: ox,
                startY: oy
            ))
        }
        mice = built
    }

    func position(for m: MouseBlueprint, at time: TimeInterval) -> CGPoint {
        let elapsed = time - startTime
        let margin = 50.0
        let rawX = m.startX + sin(elapsed * m.freqX + m.phaseX) * (screenSize.width * 0.38)
        let rawY = m.startY + sin(elapsed * m.freqY + m.phaseY) * (screenSize.height * 0.35)
        let x = min(max(rawX, margin), screenSize.width - margin)
        let y = min(max(rawY, margin), screenSize.height - margin)
        return CGPoint(x: x, y: y)
    }

    func velocityAngle(for m: MouseBlueprint, at time: TimeInterval) -> Double {
        let elapsed = time - startTime
        let dx = cos(elapsed * m.freqX + m.phaseX) * m.freqX * m.speedX
        let dy = cos(elapsed * m.freqY + m.phaseY) * m.freqY * m.speedY
        return atan2(dy, dx)
    }

    func catchMouse(_ id: UUID, position: CGPoint, at time: TimeInterval) {
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
        for m in mice where !caughtIDs.contains(m.id) {
            let pos = position(for: m, at: time)
            let dist = hypot(pos.x - point.x, pos.y - point.y)
            let hitRadius = Double(m.size) * 1.05
            if dist < hitRadius && dist < bestDist {
                bestDist = dist
                bestID = m.id
            }
        }
        if let id = bestID, let m = mice.first(where: { $0.id == id }) {
            let pos = position(for: m, at: time)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            GameAudioManager.shared.playCatchSound("mouse_squeak")
            catchMouse(id, position: pos, at: time)
        }
    }
}

struct MouseGameView: View {
    @State private var vm = MouseViewModel()
    @State private var isPaused: Bool = false
    @State private var pausedTime: TimeInterval = 0
    @State private var pauseStartedAt: TimeInterval? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FloorBackground()
                    .ignoresSafeArea()

                TimelineView(.animation) { _ in
                    let time = isPaused ? pausedTime : vm.currentTime
                    ZStack {
                        ForEach(vm.mice) { m in
                            let pos = vm.position(for: m, at: time)
                            let angle = vm.velocityAngle(for: m, at: time)
                            let caught = vm.caughtIDs.contains(m.id)
                            let catchTime = vm.catchTimes[m.id] ?? time
                            let progress = caught ? min((time - catchTime) / 0.5, 1.0) : 0
                            MouseView(size: m.size, angle: angle, catchProgress: progress)
                                .position(pos)
                        }
                        ForEach(vm.catchEffects, id: \.id) { effect in
                            let progress = min((time - effect.time) / 0.7, 1.0)
                            MouseCatchEffect(progress: progress)
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
                        title: "Mouse Catch",
                        subtitle: "Mäuse sausen in zufälligen Kurven über den Boden und verschwinden kurz, sobald eine Pfote sie erwischt.",
                        score: vm.score,
                        scoreColor: Color(hue: 0.08, saturation: 0.75, brightness: 0.85),
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
                GameAudioManager.shared.playLoop("floor_loop")
            }
            .onDisappear {
                GameAudioManager.shared.stopLoop("floor_loop")
            }
            .task(id: isPaused) {
                while !Task.isCancelled {
                    if !isPaused {
                        vm.update(at: Date.timeIntervalSinceReferenceDate)
                    }
                    try? await Task.sleep(for: .milliseconds(16))
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct MouseView: View {
    let size: CGFloat
    let angle: Double
    let catchProgress: Double

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(hue: 0.0, saturation: 0.0, brightness: 0.72))
                .frame(width: size * 0.55, height: size * 0.38)
                .offset(y: size * 0.04)

            Circle()
                .fill(Color(hue: 0.0, saturation: 0.0, brightness: 0.78))
                .frame(width: size * 0.44, height: size * 0.44)
                .offset(x: -size * 0.1, y: -size * 0.04)

            Circle()
                .fill(Color(hue: 0.0, saturation: 0.0, brightness: 0.85))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: -size * 0.24, y: -size * 0.14)

            Circle()
                .fill(Color(hue: 0.95, saturation: 0.55, brightness: 0.9))
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: -size * 0.24, y: -size * 0.14)

            Circle()
                .fill(Color(hue: 0.0, saturation: 0.0, brightness: 0.85))
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: -size * 0.06, y: -size * 0.24)

            Circle()
                .fill(Color(hue: 0.95, saturation: 0.55, brightness: 0.9))
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: -size * 0.06, y: -size * 0.24)

            Circle()
                .fill(.black)
                .frame(width: size * 0.07)
                .offset(x: -size * 0.32, y: -size * 0.02)

            Path { path in
                path.move(to: CGPoint(x: size * 0.3, y: size * 0.06))
                path.addQuadCurve(
                    to: CGPoint(x: size * 0.6, y: size * 0.0),
                    control: CGPoint(x: size * 0.45, y: size * 0.18)
                )
            }
            .stroke(Color(hue: 0.95, saturation: 0.35, brightness: 0.85), lineWidth: 2.5)
        }
        .frame(width: size, height: size)
        .rotationEffect(.radians(angle))
        .scaleEffect(1.0 + catchProgress * 0.5)
        .opacity(1.0 - catchProgress)
        .rotationEffect(.degrees(catchProgress * 270))
        .allowsHitTesting(false)
    }
}

struct MouseCatchEffect: View {
    let progress: Double

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                let angle = Double(i) * .pi * 2 / 5 - .pi / 2
                Image(systemName: "sparkles")
                    .font(.system(size: max(1, 22 - progress * 10)))
                    .foregroundStyle(.yellow)
                    .offset(
                        x: progress * 55 * cos(angle),
                        y: progress * 55 * sin(angle)
                    )
                    .opacity(1.0 - progress)
            }
            Image(systemName: "pawprint.fill")
                .font(.system(size: max(1, 30 * (1 - progress))))
                .foregroundStyle(Color(hue: 0.08, saturation: 0.8, brightness: 0.9))
                .opacity(progress < 0.4 ? 1 : 1 - (progress - 0.4) / 0.6)
                .scaleEffect(0.5 + progress * 0.8)
        }
        .allowsHitTesting(false)
    }
}

struct FloorBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.08, saturation: 0.28, brightness: 0.93),
                    Color(hue: 0.09, saturation: 0.35, brightness: 0.80),
                    Color(hue: 0.07, saturation: 0.42, brightness: 0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { geo in
                let cols = 8
                let rows = 14
                let w = geo.size.width / CGFloat(cols)
                let h = geo.size.height / CGFloat(rows)
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        let offset = row % 2 == 0 ? 0.0 : w * 0.5
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hue: 0.08, saturation: 0.3, brightness: col % 2 == 0 ? 0.88 : 0.82).opacity(0.45))
                            .frame(width: w - 2, height: h - 2)
                            .position(
                                x: CGFloat(col) * w + w / 2 + offset,
                                y: CGFloat(row) * h + h / 2
                            )
                    }
                }
            }

            LinearGradient(
                colors: [.black.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.15)
            )
        }
        .allowsHitTesting(false)
    }
}
