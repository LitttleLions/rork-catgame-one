import SwiftUI

enum GameType: String, Hashable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case fishing = "fishing"
    case tick = "tick"
    case mouse = "mouse"
    case ladybug = "ladybug"
}

struct ContentView: View {
    @State private var selectedGame: GameType? = nil

    var body: some View {
        HomeView(onSelect: { game in
            selectedGame = game
        })
        .fullScreenCover(item: $selectedGame) { type in
            switch type {
            case .fishing: FishingGameView()
            case .tick: TickGameView()
            case .mouse: MouseGameView()
            case .ladybug: LadybugGameView()
            }
        }
    }
}
