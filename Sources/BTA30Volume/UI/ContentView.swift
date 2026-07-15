import SwiftUI

/// Popover root view: manages the main ↔ settings screen transition.
struct ContentView: View {
    @ObservedObject var model: AppModel

    private enum Screen {
        case main
        case settings
    }
    @State private var screen: Screen = .main

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        Group {
            switch screen {
            case .main:
                MainView(model: model) {
                    withAnimation(.easeInOut(duration: 0.18)) { screen = .settings }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            case .settings:
                SettingsView(model: model) {
                    withAnimation(.easeInOut(duration: 0.18)) { screen = .main }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: 336)
        .onDisappear {
            model.keyboard.endRecording()
            screen = .main
        }
    }
}
