import SwiftUI

/// 하단 플로팅 탭바(304×58, Figma 299:121). 하단 바 디자인은 수정 예정이라 크기·색은 위쪽 상수에 모아 둔다.
///
/// 아이콘은 단색 PNG를 템플릿으로 칠한다. 디자인에서 비활성 탭은 같은 아이콘에 투명도 10%를 준 것이라
/// 활성/비활성 그림을 따로 두지 않는다.
struct WeGoTabBar: View {
    @Binding var selection: MainTab

    private let barSize = CGSize(width: 304, height: 58)
    private let horizontalPadding: CGFloat = 20
    private let inactiveOpacity = 0.1

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.available, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Image(tab.iconName)
                        .renderingMode(.template)
                        .foregroundStyle(Color.black.opacity(selection == tab ? 1 : inactiveOpacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(width: barSize.width, height: barSize.height)
        .background(Color.white, in: Capsule())
    }
}

private extension MainTab {
    /// Figma 299:121의 탭 아이콘(홈·책·자전거·사람). 크기가 아이콘마다 달라 그림 크기를 그대로 쓴다.
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
    WeGoTabBar(selection: $selection)
        .padding(40)
        .background(Color.gray.opacity(0.3))
}
