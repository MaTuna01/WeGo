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
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active:
                        Task { await appState.checkMinimumVersion() }
                    case .background:
                        // 백그라운드에서 그대로 종료될 수 있으니 진행 중 주행을 저장해 둔다.
                        appState.persistActiveRide()
                    default:
                        break
                    }
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

            // 최소 지원 버전보다 낮으면 어느 화면이든 덮고 App Store로만 보낸다.
            if appState.isUpdateRequired {
                UpdateRequiredView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: appState.phase)
        .animation(.easeInOut(duration: 0.35), value: appState.isUpdateRequired)
    }
}
