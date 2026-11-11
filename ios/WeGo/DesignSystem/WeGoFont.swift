import SwiftUI

/// 디자인 시스템 서체: Pretendard (Bold / SemiBold / Medium / Regular).
/// 폰트 파일은 scripts/fetch-figma-assets.sh가 Resources/Fonts에 넣고, Config/Info.plist의 UIAppFonts로 등록한다.
/// 파일이 없으면 SwiftUI가 같은 크기의 시스템 폰트로 대체한다.
enum WeGoFont {
    enum Weight: String {
        case regular = "Regular"
        case medium = "Medium"
        case semibold = "SemiBold"
        case bold = "Bold"
    }

    static func pretendard(_ weight: Weight, _ size: CGFloat) -> Font {
        .custom("Pretendard-\(weight.rawValue)", size: size)
    }
}

extension View {
    /// Figma 텍스트 속성(굵기·크기·자간·행간)을 한 번에 적용한다.
    /// - lineHeight: Figma의 line-height(pt). 폰트 기본 행 높이(≈1.2배)를 뺀 만큼 lineSpacing으로 준다.
    func wegoFont(
        _ weight: WeGoFont.Weight,
        _ size: CGFloat,
        tracking: CGFloat = 0,
        lineHeight: CGFloat? = nil
    ) -> some View {
        self
            .font(WeGoFont.pretendard(weight, size))
            .tracking(tracking)
            .lineSpacing(max(0, (lineHeight ?? 0) - size * 1.2))
    }
}
