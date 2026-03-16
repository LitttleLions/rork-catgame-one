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
        .onAppear { appeared = true }
    }
}

struct GameCardView: View {
    let game: GameInfo
    @State private var hovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black
                .frame(height: 190)
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
                .clipShape(.rect(cornerRadius: 22))

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(.rect(cornerRadius: 22))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(game.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(game.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .allowsHitTesting(false)

            Text(game.emoji)
                .font(.system(size: 54))
                .shadow(color: .black.opacity(0.3), radius: 6)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 28)
                .padding(.bottom, 36)
                .offset(y: hovered ? -6 : 0)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: hovered)
                .allowsHitTesting(false)
        }
        .frame(height: 190)
        .shadow(color: game.gradientColors[0].opacity(0.45), radius: 16, y: 8)
        .onAppear { hovered = true }
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
