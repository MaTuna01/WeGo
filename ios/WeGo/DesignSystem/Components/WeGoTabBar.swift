import SwiftUI

/// 하단 탭바(Figma wireframe 430:1942 등 모든 탭 화면): 화면 폭 전체 흰 바, 위쪽 모서리만 둥글고,
/// 아이콘 아래에 글자 라벨(홈 / 저장 / 라이딩 / MY)을 둔다.
///
/// 아이콘은 단색 PNG를 템플릿으로 칠하고, 비활성 탭은 같은 아이콘을 옅게 칠한다.
/// 디자인의 새 아이콘(주황 문이 있는 집, 오리 얼굴 MY 등)을 받으면 그림만 바꾼다.
struct WeGoTabBar: View {
    @Binding var selection: MainTab
    /// 화면 아래 안전 영역(홈 인디케이터). 바 배경은 화면 끝까지 칠하고 내용은 그 위에 둔다.
    var bottomInset: CGFloat = 0

    private let inactiveColor = WeGoColor.gray300

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
            // 그림마다 투명 여백이 달라 원래 크기 그대로 두고, 칸 밖으로 넘치는 여백은 겹치게 둔다.
            Image(tab.iconName)
                .renderingMode(.template)
                .frame(height: TabBarLayout.iconBoxHeight)
            Text(tab.title)
                .wegoFont(.medium, 12, tracking: -0.3)
        }
        .foregroundStyle(isSelected ? Color.black : inactiveColor)
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
    /// 탭 아이콘(홈, 책, 자전거, 사람)
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
