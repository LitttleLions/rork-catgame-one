import SwiftUI

nonisolated struct TickBlueprint: Identifiable, Sendable {
    let id = UUID()
    let size: CGFloat
    let speed: Double
    let directionChangeInterval: Double
    let initialAngle: Double
    let startX: Double
    let startY: Double
    let phaseX: Double
    let phaseY: Double
    let freqX: Double
    let freqY: Double
}

@Observable
class TickViewModel {
    var ticks: [TickBlueprint] = []
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
        ticks = (0..<5).map { i in
            TickBlueprint(
                size: CGFloat.random(in: 38...52),
                speed: Double.random(in: 90...170),
                directionChangeInterval: Double.random(in: 0.8...2.0),
                initialAngle: Double(i) * 2.1,
                startX: Double.random(in: 0.2...0.8) * size.width,
                startY: Double.random(in: 0.2...0.8) * size.height,
                phaseX: Double(i) * 1.3,
                phaseY: Double(i) * 2.1,
                freqX: Double.random(in: 0.4...0.9),
                freqY: Double.random(in: 0.5...1.1)
            )
        }
    }

    func position(for t: TickBlueprint, at time: TimeInterval) -> CGPoint {
        let elapsed = time - startTime
        let margin = 40.0
        let rangeX = screenSize.width - 2 * margin
        let rangeY = screenSize.height - 2 * margin
        let rawX = t.startX + sin(elapsed * t.freqX + t.phaseX) * rangeX * 0.45
        let rawY = t.startY + sin(elapsed * t.freqY + t.phaseY) * rangeY * 0.45
        let x = min(max(rawX, margin), screenSize.width - margin)
        let y = min(max(rawY, margin), screenSize.height - margin)
        return CGPoint(x: x, y: y)
    }

    func catchTick(_ id: UUID, position: CGPoint, at time: TimeInterval) {
        guard !caughtIDs.contains(id) else { return }
        caughtIDs.insert(id)
        catchTimes[id] = time
        catchEffects.append((id: UUID(), position: position, time: time))
        score += 1
    }

    func update(at time: TimeInterval) {
        currentTime = time
        let toRespawn = catchTimes.filter { time - $0.value > 1.5 }.map(\.key)
        for id in toRespawn {
            caughtIDs.remove(id)
            catchTimes.removeValue(forKey: id)
        }
        catchEffects = catchEffects.filter { time - $0.time < 0.8 }
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
        for t in ticks where !caughtIDs.contains(t.id) {
            let pos = position(for: t, at: time)
            let dist = hypot(pos.x - point.x, pos.y - point.y)
            let hitRadius = Double(t.size) * 1.6
            if dist < hitRadius && dist < bestDist {
                bestDist = dist
                bestID = t.id
            }
        }
        if let id = bestID, let t = ticks.first(where: { $0.id == id }) {
            let pos = position(for: t, at: time)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            catchTick(id, position: pos, at: time)
        }
    }
}

struct TickGameView: View {
    @State private var vm = TickViewModel()
    @State private var isPaused: Bool = false
    @State private var pausedTime: TimeInterval = 0
    @State private var pauseStartedAt: TimeInterval? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                GrassBackground()
                    .ignoresSafeArea()

                TimelineView(.animation) { context in
                    let liveTime = context.date.timeIntervalSinceReferenceDate
                    let time = isPaused ? pausedTime : liveTime
                    let _ = vm.update(at: time)
                    ZStack {
                        ForEach(vm.ticks) { t in
                            let pos = vm.position(for: t, at: time)
                            let caught = vm.caughtIDs.contains(t.id)
                            let catchTime = vm.catchTimes[t.id] ?? time
                            let progress = caught ? min((time - catchTime) / 0.5, 1.0) : 0
                            TickView(size: t.size, catchProgress: progress)
                                .position(pos)
                        }
                        ForEach(vm.catchEffects, id: \.id) { effect in
                            let progress = min((time - effect.time) / 0.7, 1.0)
                            CatchStarBurst(progress: progress, color: Color(hue: 0.32, saturation: 0.8, brightness: 0.7))
                                .position(effect.position)
                        }
                    }
                }

                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                guard !isPaused else { return }
                                vm.handleTap(at: value.location)
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard !isPaused else { return }
                                vm.handleTap(at: value.location)
                            }
                    )
                    .zIndex(5)

                VStack(spacing: 0) {
                    GameHeaderView(
                        title: "Find a Tick",
                        subtitle: "Zecken krabbeln in wechselnden Bögen über die Wiese und ploppen nach einem Treffer kurz weg.",
                        score: vm.score,
                        scoreColor: Color(hue: 0.32, saturation: 0.7, brightness: 0.6),
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
            }
        }
        .ignoresSafeArea()
    }
}

struct TickView: View {
    let size: CGFloat
    let catchProgress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hue: 0.07, saturation: 0.85, brightness: 0.25))
                .frame(width: size * 0.55, height: size * 0.45)

            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4.0
                Capsule()
                    .fill(Color(hue: 0.07, saturation: 0.7, brightness: 0.2))
                    .frame(width: size * 0.28, height: size * 0.07)
                    .offset(x: size * 0.32)
                    .rotationEffect(.degrees(angle * 180 / .pi))
                    .offset(x: size * 0.05 * cos(angle), y: size * 0.05 * sin(angle))
            }

            Ellipse()
                .fill(Color(hue: 0.6, saturation: 0.5, brightness: 0.7).opacity(0.6))
                .frame(width: size * 0.18, height: size * 0.12)
                .offset(x: -size * 0.06, y: -size * 0.08)
        }
        .frame(width: size, height: size)
        .scaleEffect(1.0 + catchProgress * 0.8)
        .opacity(1.0 - catchProgress)
        .rotationEffect(.degrees(catchProgress * 180))
        .allowsHitTesting(false)
    }
}

struct GrassBackground: View {
    @State private var sway = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.31, saturation: 0.65, brightness: 0.52),
                    Color(hue: 0.29, saturation: 0.7, brightness: 0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [Color(hue: 0.55, saturation: 0.5, brightness: 0.85).opacity(0.25), .clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.3)
            )

            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<30, id: \.self) { i in
                        let h = CGFloat(40 + (i % 5) * 18)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hue: 0.33, saturation: 0.75, brightness: 0.55).opacity(0.8))
                            .frame(width: 13, height: h)
                            .rotationEffect(.degrees(sway ? Double(i % 3 - 1) * 5 : Double(i % 3 - 1) * -3), anchor: .bottom)
                            .animation(
                                .easeInOut(duration: 1.5 + Double(i % 4) * 0.3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.08),
                                value: sway
                            )
                    }
                }
                .frame(height: 90, alignment: .bottom)
                .clipped()
            }

            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<18, id: \.self) { i in
                        let h = CGFloat(25 + (i % 3) * 10)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hue: 0.34, saturation: 0.8, brightness: 0.45).opacity(0.9))
                            .frame(width: 20, height: h)
                            .rotationEffect(.degrees(sway ? Double(i % 2) * 4 : -Double(i % 2) * 4), anchor: .bottom)
                            .animation(
                                .easeInOut(duration: 2 + Double(i % 3) * 0.4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.12),
                                value: sway
                            )
                    }
                }
                .frame(height: 50, alignment: .bottom)
                .clipped()
            }
        }
        .allowsHitTesting(false)
        .onAppear { sway = true }
    }
}

struct CatchStarBurst: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * .pi / 3
                let dist = progress * 50
                Image(systemName: "star.fill")
                    .font(.system(size: max(1, 20 - progress * 14)))
                    .foregroundStyle(color)
                    .offset(x: dist * cos(angle), y: dist * sin(angle))
                    .opacity(1.0 - progress)
            }
        }
        .allowsHitTesting(false)
    }
}
