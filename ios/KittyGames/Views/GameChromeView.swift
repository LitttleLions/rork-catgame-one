import SwiftUI

struct GameHeaderView: View {
    let title: String
    let subtitle: String
    let score: Int
    let scoreColor: Color
    let onExit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onExit) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                ScoreBadge(score: score, color: scoreColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 58)
        }
    }
}

struct GameControlBar: View {
    let isPaused: Bool
    let onTogglePause: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(isPaused ? "Spiel pausiert" : "Tippen oder mit der Pfote über den Bildschirm wischen")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))

            HStack(spacing: 12) {
                Button(action: onTogglePause) {
                    Label(isPaused ? "Start" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameActionButtonStyle(fill: .white.opacity(0.24)))

                Button(action: onExit) {
                    Label("Beenden", systemImage: "xmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameActionButtonStyle(fill: .black.opacity(0.42)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 26)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.2), .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct GameActionButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(fill.opacity(configuration.isPressed ? 0.72 : 1.0))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.24), lineWidth: 1)
                    }
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
