import SwiftUI

@main
struct WeGoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(appState.location)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            switch appState.phase {
            case .splash:
                SplashView().transition(.opacity)
            case .login:
                LoginView().transition(.opacity)
            case .main:
                MainView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.phase)
    }
}
