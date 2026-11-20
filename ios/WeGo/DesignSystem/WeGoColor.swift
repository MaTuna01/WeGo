import SwiftUI

/// Figma "로고,디자인시스템 › 디자인시스템 › Color System" (node 80:509) 기준 색상.
enum WeGoColor {
    // MARK: 브랜드
    static let primary = Color(hex: 0xFF7300)
    /// 와이어프레임의 강조 주황(#FC9931, #FB9830)도 이 토큰으로 통일했다.
    static let primaryLight = Color(hex: 0xFCA035)
    /// 시안 라벨은 97DBB6이지만 실제 칠해진 값은 5DC4EF — 실제 값을 따른다.
    static let sky = Color(hex: 0x5DC4EF)
    static let cream = Color(hex: 0xFCF7F3)
    static let peach = Color(hex: 0xFCE2D5)
    static let red = Color(hex: 0xFC5B31)
    /// 시안 라벨은 DDED59이지만 실제 칠해진 값은 F2D72A — 실제 값을 따른다.
    static let yellow = Color(hex: 0xF2D72A)

    // MARK: 그레이스케일
    static let gray900 = Color(hex: 0x1B1B1B)
    static let gray800 = Color(hex: 0x333333)
    static let gray500 = Color(hex: 0x999999)
    static let gray300 = Color(hex: 0xD0D0D0)
    static let gray100 = Color(hex: 0xF4F4F4)
    static let white = Color.white

    // MARK: 와이어프레임 화면에서 쓰는 값 (디자인 시스템 확정 시 위 토큰으로 흡수)
    static let surface = Color(hex: 0xF1F1F1)      // 바텀시트, 검색바, 필터 칩
    static let placeholder = Color(hex: 0xC7C7C7)  // 코스 썸네일 자리
    static let chip = Color(hex: 0xD9D9D9)         // 시트 핸들, 코스 탭 칩, 보조 버튼
    static let tabBar = Color(hex: 0xEEEEEE)       // 디자인시스템 탭바(138:461)
    static let buttonDark = Color(hex: 0x2E2E2E)   // "대여하러 가기"
    static let textBody = Color(hex: 0x484848)
    static let textCaption = Color(hex: 0x424242)
    static let border = Color(hex: 0xCFCFCF)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
