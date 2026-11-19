import SwiftUI

/// 최소 지원 버전보다 낮을 때 앱 전체를 덮는 업데이트 안내. 닫기 버튼 없이 App Store로만 보낸다.
/// 디자인이 아직 없어 로그인 화면의 오리 일러스트와 검정 버튼을 그대로 쓴다.
struct UpdateRequiredView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            DuckRiderImage(width: 208, height: 216)
                .accessibilityHidden(true)

            Text("새 버전이 나왔어요")
                .wegoFont(.bold, 26, tracking: -0.6)
                .foregroundStyle(.black)
                .padding(.top, 24)

            Text("지금 버전은 더 이상 지원하지 않아요.\n업데이트한 뒤 다시 이용해 주세요.")
                .wegoFont(.regular, 16, tracking: -0.4, lineHeight: 24)
                .multilineTextAlignment(.center)
                .foregroundStyle(WeGoColor.textBody)
                .padding(.top, 12)

            Spacer()

            SocialLoginButton(icon: nil, title: "업데이트하러 가기", style: .dark) {
                openURL(AppStoreLink.current)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    UpdateRequiredView()
}
