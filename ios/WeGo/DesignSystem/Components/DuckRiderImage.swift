import SwiftUI

/// "주황 헬멧 오리 자전거 라이딩" 일러스트. Figma와 같은 비율로 잘라(crop) 보여준다.
/// (원본 이미지는 컨테이너보다 118.75% × 114.57% 크고, 왼쪽 위로 18.75% / 14.57% 밀려 있다.)
struct DuckRiderImage: View {
    var assetName = "duckRider"
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Image(assetName)
            .resizable()
            .frame(width: width * 1.1875, height: height * 1.1457)
            .offset(x: -width * 0.1875, y: -height * 0.1457)
            .frame(width: width, height: height, alignment: .topLeading)
            .clipped()
            .accessibilityHidden(true)
    }
}
