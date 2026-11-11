import SwiftUI

/// 지도 위에 고정된 바텀시트 배경(와이어프레임 Rectangle 34635110).
struct BottomSheetContainer<Content: View>: View {
    var showsHandle = true
    var handleTopPadding: CGFloat = 10
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            if showsHandle {
                Capsule()
                    .fill(WeGoColor.chip)
                    .frame(width: 44, height: 5)
                    .padding(.top, handleTopPadding)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            WeGoColor.surface,
            in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous)
        )
    }
}
