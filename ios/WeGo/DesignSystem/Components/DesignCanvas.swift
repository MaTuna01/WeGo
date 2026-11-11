import SwiftUI

/// Figma 프레임(iPhone 17, 402×874pt) 좌표를 그대로 써서 일러스트 위주 화면을 배치하는 캔버스.
/// 화면 크기에 맞게 비율을 유지하며 확대·축소한다. 버튼·목록 같은 UI에는 쓰지 말고 일반 레이아웃을 쓴다.
struct DesignCanvas<Content: View>: View {
    let designWidth: CGFloat = 402
    let designHeight: CGFloat = 874
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            ZStack(alignment: .topLeading) {
                content
            }
            .frame(width: designWidth, height: designHeight, alignment: .topLeading)
            .clipped()
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: designWidth * scale, height: designHeight * scale, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}
