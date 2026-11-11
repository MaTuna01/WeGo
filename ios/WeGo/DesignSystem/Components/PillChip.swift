import SwiftUI

/// 지도 상단 필터 칩(90×28)과 정류장 시트의 코스 탭 칩(76×26).
/// 와이어프레임에는 선택 상태가 없어서, 선택된 칩은 gray800 배경으로 임시 구분한다.
struct PillChip: View {
    let title: String
    let isSelected: Bool
    var width: CGFloat
    var height: CGFloat = 28
    var background: Color = WeGoColor.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .wegoFont(isSelected ? .semibold : .regular, 14, tracking: -0.7)
                .foregroundStyle(isSelected ? Color.white : Color.black)
                .lineLimit(1)
                .frame(width: width, height: height)
                .background(isSelected ? WeGoColor.gray800 : background, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
