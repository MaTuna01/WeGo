import SwiftUI

/// 로그인 후 메인. 화면 아래에 탭바를 얹는다.
struct MainView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        // 아래 안전 영역을 읽은 뒤 화면 끝까지 그린다. 탭바 높이(내용 + 안전 영역)는 환경값으로 각 화면에 알린다.
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom
            ZStack(alignment: .bottom) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.tabBarHeight, showsTabBar ? TabBarLayout.contentHeight + bottomInset : 0)

                if showsTabBar {
                    WeGoTabBar(selection: $appState.selectedTab, bottomInset: bottomInset)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// 주행 중(라이딩 탭에 진행 중인 주행이 있을 때)에는 탭바를 숨긴다(Figma 299:343).
    private var showsTabBar: Bool {
        !(appState.selectedTab == .ride && appState.ride != nil)
    }

    @ViewBuilder
    private var tabContent: some View {
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
}

#Preview {
    let state = AppState()
    state.phase = .main
    return MainView()
        .environment(state)
        .environment(state.location)
}
