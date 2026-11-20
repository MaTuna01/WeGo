import Foundation

/// 앱 밖으로 여는 위고 웹 페이지. App Store Connect에 적는 개인정보 처리방침 URL, 지원 URL과 같은 주소를 쓴다.
/// 심사 전에 페이지가 열려 있어야 한다(열리지 않으면 반려 사유).
enum AppLinks {
    static let privacyPolicy = URL(string: "https://wegoride.site/privacy")!
    static let support = URL(string: "https://wegoride.site/support")!
}
