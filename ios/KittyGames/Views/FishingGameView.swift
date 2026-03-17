import SwiftUI

nonisolated struct FishBlueprint: Identifiable, Sendable {
    let id = UUID()
    let speed: Double
    let size: CGFloat
    let baselineRatio: Double
    let waveFreq: Double
    let waveAmplitude: Double
    let phase: Double
    let startOffset: Double
    let colorVariant: Int
}

@Observable
class FishingViewModel {
    var fish: [FishBlueprint] = []
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
        fish = (0..<6).map { i in
            let goRight = i % 2 == 0
            return FishBlueprint(
                speed: goRight ? Double.random(in: 70...140) : -Double.random(in: 70...140),
                size: CGFloat.random(in: 65...95),
                baselineRatio: 0.18 + Double(i) * 0.12,
                waveFreq: Double.random(in: 0.7...1.8),
                waveAmplitude: Double.random(in: 22...55),
                phase: Double(i) * .pi / 3.0,
                startOffset: Double(i) * size.width / 5.5,
                colorVariant: i
            )
        }
    }

    func position(for f: FishBlueprint, at time: TimeInterval) -> CGPoint {
        let elapsed = time - startTime
        let margin = 100.0
        let totalWidth = screenSize.width + 2 * margin
        var x: Double
        if f.speed > 0 {
            let raw = f.speed * elapsed + f.startOffset + margin
            x = raw.truncatingRemainder(dividingBy: totalWidth) - margin
        } else {
            let raw = (screenSize.width + margin) + f.startOffset + abs(f.speed) * elapsed
            x = screenSize.width + margin - (raw.truncatingRemainder(dividingBy: totalWidth))
            if x < -margin { x += totalWidth }
        }
        let y = screenSize.height * f.baselineRatio
            + sin(elapsed * f.waveFreq + f.phase) * f.waveAmplitude
        return CGPoint(x: x, y: y)
    }

    func catchFish(_ id: UUID, position: CGPoint, at time: TimeInterval) {
        guard !caughtIDs.contains(id) else { return }
        caughtIDs.insert(id)
        catchTimes[id] = time
        catchEffects.append((id: UUID(), position: position, time: time))
        score += 1
    }

    func update(at time: TimeInterval) {
        currentTime = time
        let toRespawn = catchTimes.filter { time - $0.value > 1.8 }.map(\.key)
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
        for f in fish where !caughtIDs.contains(f.id) {
            let pos = position(for: f, at: time)
            let dist = hypot(pos.x - point.x, pos.y - point.y)
            let hitRadius = Double(f.size) * 1.05
            if dist < hitRadius && dist < bestDist {
                bestDist = dist
                bestID = f.id
            }
        }
        if let id = bestID {
            let pos = position(for: fish.first(where: { $0.id == id })!, at: time)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            GameAudioManager.shared.playCatchSound("bubble_pop")
            catchFish(id, position: pos, at: time)
        }
    }
}

struct FishingGameView: View {
    @State private var vm = FishingViewModel()
    @State private var isPaused: Bool = false
    @State private var pausedTime: TimeInterval = 0
    @State private var pauseStartedAt: TimeInterval? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                UnderwaterBackground()
                    .ignoresSafeArea()

                TimelineView(.animation) { _ in
                    let time = isPaused ? pausedTime : vm.currentTime
                    ZStack {
                        ForEach(vm.fish) { f in
                            let pos = vm.position(for: f, at: time)
                            let caught = vm.caughtIDs.contains(f.id)
                            let catchTime = vm.catchTimes[f.id] ?? time
                            let progress = caught ? min((time - catchTime) / 0.5, 1.0) : 0
                            FishShapeView(
                                colorVariant: f.colorVariant,
                                size: f.size,
                                facingLeft: f.speed < 0,
                                catchProgress: progress
                            )
                            .position(pos)
                        }
                        ForEach(vm.catchEffects, id: \.id) { effect in
                            let progress = min((time - effect.time) / 0.7, 1.0)
                            SplashEffect(progress: progress)
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
                        title: "Cat Fishing",
                        subtitle: "Fische schwimmen in Wellen quer über den Bildschirm und verschwinden kurz, wenn sie getroffen werden.",
                        score: vm.score,
                        scoreColor: Color(hue: 0.56, saturation: 0.8, brightness: 0.9),
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
                GameAudioManager.shared.playLoop("underwater_loop")
            }
            .onDisappear {
                GameAudioManager.shared.stopLoop("underwater_loop")
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

struct FishTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: cx - w * 0.1, y: cy))
        path.addLine(to: CGPoint(x: cx + w * 0.5, y: cy - h * 0.5))
        path.addLine(to: CGPoint(x: cx + w * 0.5, y: cy + h * 0.5))
        path.closeSubpath()
        return path
    }
}

struct FishTopFin: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: cx - w * 0.4, y: cy + h * 0.4))
        path.addQuadCurve(
            to: CGPoint(x: cx + w * 0.4, y: cy + h * 0.4),
            control: CGPoint(x: cx, y: cy - h * 0.6)
        )
        path.closeSubpath()
        return path
    }
}

struct FishShapeView: View {
    let colorVariant: Int
    let size: CGFloat
    let facingLeft: Bool
    let catchProgress: Double

    private var bodyColor: Color {
        let colors: [Color] = [
            Color(hue: 0.07, saturation: 0.9, brightness: 0.95),
            Color(hue: 0.58, saturation: 0.85, brightness: 0.95),
            Color(hue: 0.15, saturation: 0.85, brightness: 0.95),
            Color(hue: 0.75, saturation: 0.75, brightness: 0.9),
            Color(hue: 0.48, saturation: 0.8, brightness: 0.88),
            Color(hue: 0.92, saturation: 0.7, brightness: 0.95),
        ]
        return colors[colorVariant % colors.count]
    }

    private var stripeColor: Color {
        bodyColor.opacity(0.55)
    }

    var body: some View {
        ZStack {
            FishTailShape()
                .fill(bodyColor.opacity(0.8))
                .frame(width: size * 0.5, height: size * 0.45)
                .offset(x: size * 0.28)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [bodyColor, bodyColor.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.68, height: size * 0.38)

            FishTopFin()
                .fill(bodyColor.opacity(0.75))
                .frame(width: size * 0.28, height: size * 0.2)
                .offset(x: -size * 0.06, y: -size * 0.27)

            Path { path in
                path.move(to: CGPoint(x: -size * 0.05, y: -size * 0.06))
                path.addArc(
                    center: CGPoint(x: -size * 0.05, y: size * 0.02),
                    radius: size * 0.1,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(90),
                    clockwise: false
                )
            }
            .stroke(stripeColor, lineWidth: 1.5)

            Path { path in
                path.move(to: CGPoint(x: size * 0.08, y: -size * 0.07))
                path.addArc(
                    center: CGPoint(x: size * 0.08, y: size * 0.01),
                    radius: size * 0.1,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(90),
                    clockwise: false
                )
            }
            .stroke(stripeColor, lineWidth: 1.5)

            Circle()
                .fill(.white)
                .frame(width: size * 0.14, height: size * 0.14)
                .offset(x: -size * 0.24, y: -size * 0.04)

            Circle()
                .fill(.black)
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: -size * 0.25, y: -size * 0.04)

            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: size * 0.035)
                .offset(x: -size * 0.26, y: -size * 0.065)
        }
        .frame(width: size, height: size)
        .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
        .scaleEffect(1.0 + catchProgress * 0.6)
        .opacity(1.0 - catchProgress)
        .rotationEffect(.degrees(catchProgress * 360))
        .allowsHitTesting(false)
    }
}

struct SplashEffect: View {
    let progress: Double

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * .pi / 4
                let dist = progress * 55
                Circle()
                    .fill(Color(hue: 0.55, saturation: 0.7, brightness: 0.95).opacity(1 - progress))
                    .frame(width: max(0, 10 - progress * 8), height: max(0, 10 - progress * 8))
                    .offset(x: dist * cos(angle), y: dist * sin(angle))
            }
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .scaleEffect(progress < 0.3 ? progress / 0.3 : 1)
                .opacity(progress > 0.5 ? (1 - (progress - 0.5) / 0.5) : 1)
        }
        .allowsHitTesting(false)
    }
}

struct UnderwaterBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.58, saturation: 0.85, brightness: 0.35),
                    Color(hue: 0.54, saturation: 0.9, brightness: 0.55),
                    Color(hue: 0.50, saturation: 0.85, brightness: 0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.06 + Double(i % 3) * 0.03))
                    .frame(width: CGFloat(8 + i * 6))
                    .offset(
                        x: CGFloat([-120, -60, 0, 60, 120, -90, 90, -30, 30, -150, 150, 0][i % 12]),
                        y: animate
                            ? CGFloat(-400 - Double(i) * 30)
                            : CGFloat(200 + Double(i) * 20)
                    )
                    .animation(
                        .linear(duration: 4 + Double(i) * 0.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.3),
                        value: animate
                    )
            }

            VStack(spacing: 0) {
                Spacer()
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<20, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hue: 0.35, saturation: 0.7, brightness: 0.4).opacity(0.6))
                            .frame(width: 16, height: CGFloat(20 + (i % 4) * 14))
                    }
                }
                .padding(.horizontal, 4)
                .frame(height: 70, alignment: .bottom)
                .clipped()
            }

            LinearGradient(
                colors: [.white.opacity(0.06), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}

struct ScoreBadge: View {
    let score: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 13, weight: .bold))
            Text("\(score)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.35))
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.25), radius: 6)
    }
}
