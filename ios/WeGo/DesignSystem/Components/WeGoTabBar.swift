import SwiftUI

/// 하단 플로팅 탭바(304×66). 아이콘은 디자인시스템 "Iconify 활성화/비활성화" 세트.
struct WeGoTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    TabIcon(tab: tab, isActive: selection == tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 24)
        .frame(width: 304, height: 66)
        .background(WeGoColor.tabBar, in: Capsule())
    }
}

private struct TabIcon: View {
    let tab: MainTab
    let isActive: Bool

    var body: some View {
        switch tab {
        case .home:
            Image(isActive ? "tabHomeOn" : "tabHomeOff")
        case .saved:
            Image(isActive ? "tabSavedOn" : "tabSavedOff")
        case .ride:
            if isActive {
                // 활성 자전거 = 자전거 몸체(Group) + 꽉 찬 바퀴 2개 (Figma 143:467, 143:509, 143:510)
                ZStack(alignment: .topLeading) {
                    Image("tabRideOn")
                    Image("tabRideWheel").offset(x: 1.73, y: 8.77)
                    Image("tabRideWheel").offset(x: 23.73, y: 8.77)
                }
            } else {
                Image("tabRideOff")
            }
        case .profile:
            Image(isActive ? "tabProfileOn" : "tabProfileOff")
        }
    }
}
