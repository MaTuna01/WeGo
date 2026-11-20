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
                    // 1.0 탭바에는 없는 탭(MainTab.available). 다시 넣을 때 실제 화면으로 바꾼다.
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

            // 주행 중(라이딩 탭에 진행 중인 주행이 있을 때)에는 탭바를 숨긴다(Figma 299:343).
            if !(appState.selectedTab == .ride && appState.ride != nil) {
                WeGoTabBar(selection: $appState.selectedTab)
                    .padding(.bottom, 23)
            }
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
