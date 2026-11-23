import SwiftUI

/// 하단 탭바(Figma wireframe 430:1942 등 모든 탭 화면): 화면 폭 전체 흰 바, 위쪽 모서리만 둥글고,
/// 아이콘 아래에 글자 라벨(홈 / 저장 / 라이딩 / MY)을 둔다.
///
/// 아이콘은 디자인의 활성 상태 그림(색 포함)을 그대로 쓰고, 비활성 탭은 같은 그림을 회색으로 옅게 보여 준다.
struct WeGoTabBar: View {
    @Binding var selection: MainTab
    /// 화면 아래 안전 영역(홈 인디케이터). 바 배경은 화면 끝까지 칠하고 내용은 그 위에 둔다.
    var bottomInset: CGFloat = 0

    private let inactiveLabelColor = WeGoColor.gray300
    /// 비활성 아이콘 투명도(디자인의 옅은 회색 아이콘에 맞춤)
    private let inactiveIconOpacity = 0.25

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.available, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    item(tab, isSelected: selection == tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, TabBarLayout.horizontalPadding)
        .frame(height: TabBarLayout.contentHeight)
        .padding(.bottom, bottomInset)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: TabBarLayout.cornerRadius,
                topTrailingRadius: TabBarLayout.cornerRadius,
                style: .continuous
            )
            .fill(.white)
            .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
        }
    }

    private func item(_ tab: MainTab, isSelected: Bool) -> some View {
        VStack(spacing: 2) {
            Image(tab.iconName)
                .renderingMode(.original)
                .grayscale(isSelected ? 0 : 1)
                .opacity(isSelected ? 1 : inactiveIconOpacity)
                .frame(height: TabBarLayout.iconBoxHeight)
            Text(tab.title)
                .wegoFont(.medium, 12, tracking: -0.3)
                .foregroundStyle(isSelected ? Color.black : inactiveLabelColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }
}

/// 탭바 크기. 탭바에 가리지 않아야 하는 화면은 환경값 `tabBarHeight`(내용 + 아래 안전 영역)를 쓴다.
enum TabBarLayout {
    /// 아이콘과 라벨이 들어가는 높이. 아이폰 17(아래 안전 영역 34)에서 디자인 높이 96이 된다.
    static let contentHeight: CGFloat = 62
    static let iconBoxHeight: CGFloat = 36
    static let cornerRadius: CGFloat = 28
    static let horizontalPadding: CGFloat = 28
}

extension EnvironmentValues {
    /// 화면 아래에서 탭바가 차지하는 높이(내용 + 아래 안전 영역). 탭바가 없는 곳에서는 0.
    @Entry var tabBarHeight: CGFloat = 0
}

private extension MainTab {
    /// 탭 아이콘(집, 책갈피, 자전거 탄 오리, 헬멧 쓴 오리 얼굴)
    var iconName: String {
        switch self {
        case .home: "tabHome"
        case .saved: "tabCourse"
        case .ride: "tabRide"
        case .profile: "tabProfile"
        }
    }
}

#Preview {
    @Previewable @State var selection: MainTab = .home
    VStack {
        Spacer()
        WeGoTabBar(selection: $selection, bottomInset: 34)
    }
    .background(Color.gray.opacity(0.3))
    .ignoresSafeArea()
}
