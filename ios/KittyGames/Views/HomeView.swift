import SwiftUI

struct HomeView: View {
    let onSelect: (GameType) -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.07, saturation: 0.15, brightness: 0.12),
                    Color(hue: 0.6, saturation: 0.2, brightness: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color(hue: 0.07, saturation: 0.9, brightness: 0.95))
                    Text("Kitty Games")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 20)
                .padding(.bottom, 6)

                Text("Spiele für deine Katze")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 28)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(Array(allGames.enumerated()), id: \.element.id) { index, game in
                            Button {
                                onSelect(game.id)
                            } label: {
                                GameCardView(game: game)
                            }
                            .buttonStyle(.plain)
                            .offset(y: appeared ? 0 : 60)
                            .opacity(appeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.75)
                                .delay(Double(index) * 0.1),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            appeared = true
        }
    }
}

struct GameCardView: View {
    let game: GameInfo
    @State private var hovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
                .frame(height: 206)
                .overlay {
                    LinearGradient(
                        colors: game.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .allowsHitTesting(false)
                }
                .overlay {
                    PatternOverlay(type: game.id)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topTrailing) {
                    GamePreviewArtView(type: game.id, isAnimating: hovered)
                        .padding(.top, 18)
                        .padding(.trailing, 18)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 24))

            LinearGradient(
                colors: [.clear, .black.opacity(0.1), .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(.rect(cornerRadius: 24))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(game.badgeTitle)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.18), in: .capsule)

                    Spacer(minLength: 0)

                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.86))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text(game.subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .allowsHitTesting(false)
        }
        .frame(height: 206)
        .shadow(color: game.gradientColors[0].opacity(0.42), radius: 18, y: 10)
        .onAppear { hovered = true }
    }
}

struct GamePreviewArtView: View {
    let type: GameType
    let isAnimating: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 106, height: 106)

            switch type {
            case .fishing:
                ZStack {
                    FishShapeView(colorVariant: 0, size: 72, facingLeft: false, catchProgress: 0)
                        .rotationEffect(.degrees(-12))
                        .offset(x: -10, y: 10)
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .offset(x: 26, y: -18)
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .offset(x: 36, y: -34)
                }
            case .tick:
                ZStack {
                    TickView(size: 62, catchProgress: 0)
                        .rotationEffect(.degrees(isAnimating ? 10 : -10))
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(width: 54, height: 6)
                        .offset(y: 32)
                }
            case .mouse:
                MouseView(size: 78, angle: isAnimating ? 0.35 : -0.2, catchProgress: 0)
                        .offset(x: -4, y: 8)
            case .ladybug:
                LadybugView(size: 76, wingOpen: isAnimating ? 0.95 : 0.35, catchProgress: 0)
                    .offset(y: 6)
            }
        }
        .frame(width: 116, height: 116)
        .scaleEffect(isAnimating ? 1.03 : 0.97)
        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isAnimating)
    }
}

struct PatternOverlay: View {
    let type: GameType

    var body: some View {
        GeometryReader { geo in
            switch type {
            case .fishing:
                BubblePattern(size: geo.size)
            case .tick:
                GrassPattern(size: geo.size)
            case .mouse:
                DotPattern(size: geo.size)
            case .ladybug:
                LeafPattern(size: geo.size)
            }
        }
    }
}

struct BubblePattern: View {
    let size: CGSize
    var body: some View {
        ForEach(0..<8, id: \.self) { i in
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1.5)
                .frame(width: CGFloat(12 + i * 8), height: CGFloat(12 + i * 8))
                .position(
                    x: CGFloat([30, 80, 150, 200, 60, 240, 120, 280][i % 8]) / 320 * size.width,
                    y: CGFloat([140, 60, 100, 150, 30, 80, 170, 50][i % 8]) / 190 * size.height
                )
        }
    }
}

struct GrassPattern: View {
    let size: CGSize
    var body: some View {
        ForEach(0..<12, id: \.self) { i in
            RoundedRectangle(cornerRadius: 3)
                .fill(.white.opacity(0.1))
                .frame(width: 4, height: CGFloat(20 + (i % 3) * 12))
                .position(
                    x: CGFloat(i) * size.width / 11,
                    y: size.height - 10
                )
        }
    }
}

struct DotPattern: View {
    let size: CGSize
    var body: some View {
        ForEach(0..<15, id: \.self) { i in
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: CGFloat(6 + (i % 4) * 4))
                .position(
                    x: CGFloat(i % 5) * size.width / 4 + 20,
                    y: CGFloat(i / 5) * size.height / 2 + 30
                )
        }
    }
}

struct LeafPattern: View {
    let size: CGSize
    var body: some View {
        ForEach(0..<6, id: \.self) { i in
            Ellipse()
                .fill(.white.opacity(0.1))
                .frame(width: CGFloat(30 + (i % 3) * 15), height: CGFloat(16 + (i % 3) * 8))
                .rotationEffect(.degrees(Double(i) * 30))
                .position(
                    x: CGFloat([40, 120, 200, 260, 80, 300][i]) / 320 * size.width,
                    y: CGFloat([160, 40, 130, 70, 100, 160][i]) / 190 * size.height
                )
        }
    }
}
