import SwiftData
import SwiftUI

@main
struct WeGoApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(appState.location)
                .modelContainer(appState.rideRecords.container)
                .onChange(of: scenePhase) { _, phase in
                    // 백그라운드에서 그대로 종료될 수 있으니 진행 중 주행을 저장해 둔다.
                    if phase == .background { appState.persistActiveRide() }
                }
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
