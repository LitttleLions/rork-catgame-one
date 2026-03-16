import SwiftUI

nonisolated struct CatchEffect: Identifiable, Sendable {
    let id = UUID()
    let position: CGPoint
    let startTime: TimeInterval
    let color: Color
}

nonisolated struct GameInfo: Identifiable, Sendable {
    let id: GameType
    let title: String
    let subtitle: String
    let emoji: String
    let gradientColors: [Color]
    let imageURL: String?
}

let allGames: [GameInfo] = [
    GameInfo(
        id: .fishing,
        title: "Cat Fishing",
        subtitle: "Fang die Fische!",
        emoji: "🐠",
        gradientColors: [Color(hue: 0.56, saturation: 0.85, brightness: 0.55), Color(hue: 0.51, saturation: 0.9, brightness: 0.75)],
        imageURL: nil
    ),
    GameInfo(
        id: .tick,
        title: "Find a Tick",
        subtitle: "Finde die Zecke!",
        emoji: "🕷️",
        gradientColors: [Color(hue: 0.32, saturation: 0.75, brightness: 0.45), Color(hue: 0.28, saturation: 0.65, brightness: 0.65)],
        imageURL: nil
    ),
    GameInfo(
        id: .mouse,
        title: "Mouse Catch",
        subtitle: "Fang die Mäuse!",
        emoji: "🐭",
        gradientColors: [Color(hue: 0.07, saturation: 0.35, brightness: 0.88), Color(hue: 0.1, saturation: 0.45, brightness: 0.65)],
        imageURL: nil
    ),
    GameInfo(
        id: .ladybug,
        title: "Ladybug",
        subtitle: "Fang die Marienkäfer!",
        emoji: "🐞",
        gradientColors: [Color(hue: 0.55, saturation: 0.4, brightness: 0.92), Color(hue: 0.33, saturation: 0.65, brightness: 0.55)],
        imageURL: nil
    )
]
