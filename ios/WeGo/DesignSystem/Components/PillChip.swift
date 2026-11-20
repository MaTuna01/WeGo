import SwiftUI

/// 지도 상단 필터 칩(90×28)과 정류장 시트의 코스 탭 칩(76×26).
/// - 지도 칩: 선택 상태 디자인이 없어 gray800 배경 + 흰 글자로 임시 구분(기본값)
/// - 코스 탭 칩: Figma 299:121대로 선택 시 주황 배경 + 검정 글자
struct PillChip: View {
    let title: String
    let isSelected: Bool
    var width: CGFloat
    var height: CGFloat = 28
    var background: Color = WeGoColor.surface
    var selectedBackground: Color = WeGoColor.gray800
    var selectedForeground: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .wegoFont(isSelected ? .semibold : .regular, 14, tracking: -0.7)
                .foregroundStyle(isSelected ? selectedForeground : Color.black)
                .lineLimit(1)
                .frame(width: width, height: height)
                .background(isSelected ? selectedBackground : background, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
