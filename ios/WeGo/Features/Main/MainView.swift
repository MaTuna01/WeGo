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
            SavedCoursesView()
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
