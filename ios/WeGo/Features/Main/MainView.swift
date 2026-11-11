import SwiftUI

/// 로그인 후 메인. 화면 위에 플로팅 탭바를 얹는다.
struct MainView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        ZStack(alignment: .bottom) {
            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                case .saved:
                    PlaceholderTabView(
                        title: "저장한 코스",
                        message: "마음에 드는 코스를 저장하면 여기에 모여요.\n이 화면은 디자인이 나오면 채울게요."
                    )
                case .ride:
                    if let ride = appState.ride {
                        RidingView(session: ride)
                    } else {
                        RideIdleView()
                    }
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            WeGoTabBar(selection: $appState.selectedTab)
                .padding(.bottom, 29)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    let state = AppState()
    state.phase = .main
    return MainView()
        .environment(state)
        .environment(state.location)
}
