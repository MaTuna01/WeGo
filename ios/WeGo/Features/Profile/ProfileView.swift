import SwiftUI

/// 내 정보 (디자인 없음, 임시 화면)
/// 1.0은 로그인이 없어서 로그인/로그아웃 버튼 대신 앱 버전만 보여준다. 로그인은 서버 연동(1.1) 때 다시 넣는다.
struct ProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("내 정보")
                .wegoFont(.bold, 24)
            Text("프로필/설정 화면은 디자인이 나오면 채울게요.\n주행 기록은 이 기기에만 저장돼요.")
                .wegoFont(.regular, 14, lineHeight: 22)
                .foregroundStyle(WeGoColor.gray500)
                .multilineTextAlignment(.center)
            Text("버전 \(Self.appVersion)")
                .wegoFont(.regular, 13)
                .foregroundStyle(WeGoColor.gray500)
                .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}

extension ProfileView {
    /// Info.plist의 마케팅 버전(예: 1.0.0)
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    }
}

/// 디자인이 아직 없는 탭에 쓰는 임시 화면
struct PlaceholderTabView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .wegoFont(.bold, 24)
            Text(message)
                .wegoFont(.regular, 14, lineHeight: 22)
                .foregroundStyle(WeGoColor.gray500)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}
