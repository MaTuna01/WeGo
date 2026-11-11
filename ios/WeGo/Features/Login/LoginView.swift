import SwiftUI

/// 로그인/회원가입 (Figma 143:386). 소셜 로그인만 노출한다.
struct LoginView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
                .frame(maxHeight: 114)

            illustration

            // 시안의 "송효선님"은 예시 이름. 로그인 전에는 이름을 모르므로 일반 호칭을 쓴다.
            Text("안녕하세요 라이더님!\n반가워요")
                .wegoFont(.semibold, 30, tracking: -1.5, lineHeight: 45)
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
                .padding(.top, 17)

            Spacer(minLength: 24)

            VStack(spacing: 11) {
                SocialLoginButton(icon: "iconGoogle", title: "구글로 시작하기", style: .light) {
                    appState.signIn(with: .google)
                }
                SocialLoginButton(icon: "iconApple", title: "Apple로 시작하기", style: .dark) {
                    appState.signIn(with: .apple)
                }
            }
            .padding(.horizontal, 14)

            Text("시작과 동시에 위고의 서비스 이용약관, 개인정보 수집 및 이용, 개인정보 위탁 제공에 동의하게 됩니다.")
                .wegoFont(.regular, 14, tracking: -0.7, lineHeight: 22)
                .foregroundStyle(WeGoColor.textCaption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 32)
                .padding(.bottom, 20)
        }
        .background(Color.white.ignoresSafeArea())
    }

    /// 오리 일러스트 뒤로 가로 주황 띠(69pt)가 지나간다.
    private var illustration: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(WeGoColor.primaryLight)
                .frame(height: 69)
                .padding(.top, 198)
            DuckRiderImage(assetName: "duckRiderLogin", width: 265, height: 275)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 275)
    }
}

struct SocialLoginButton: View {
    enum Style {
        case light
        case dark
    }

    let icon: String
    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(icon)
                Text(title)
                    .wegoFont(.medium, 20, tracking: -0.6)
            }
            .foregroundStyle(style == .dark ? Color.white : Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(style == .dark ? Color.black : Color.white, in: Capsule())
            .overlay {
                if style == .light {
                    Capsule().strokeBorder(WeGoColor.border, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LoginView()
        .environment(AppState())
}
