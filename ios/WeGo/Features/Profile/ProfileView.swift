import SwiftUI

/// 내 정보 (디자인 없음, 임시 화면)
struct ProfileView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("내 정보")
                .wegoFont(.bold, 24)
            Text("프로필·이용 기록·설정 화면은 디자인이 나오면 채울게요.")
                .wegoFont(.regular, 14)
                .foregroundStyle(WeGoColor.gray500)
                .multilineTextAlignment(.center)
            Button("로그아웃") {
                appState.signOut()
            }
            .font(WeGoFont.pretendard(.medium, 15))
            .foregroundStyle(WeGoColor.red)
            .padding(.top, 8)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
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
