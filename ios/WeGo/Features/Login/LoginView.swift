import SwiftUI

/// 로그인/회원가입 (Figma 299:38): 상단 오리 일러스트, 환영 문구, 구글 / Apple / 비로그인으로 시작하기.
///
/// 위쪽 일러스트·환영 문구는 Figma 프레임(402pt 폭) 좌표를 화면 폭에 맞춰 늘리고,
/// 버튼·약관 문구는 화면 아래에 붙여서 기기 높이가 달라도 아래 여백이 디자인과 같게 한다.
struct LoginView: View {
    @Environment(AppState.self) private var appState

    private let designWidth: CGFloat = 402

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            ZStack(alignment: .top) {
                Color.white

                // 오리 발 아래로 가로 주황 띠(y 374, 높이 69)가 지나간다.
                Rectangle()
                    .fill(WeGoColor.primaryLight)
                    .frame(height: 69 * scale)
                    .padding(.top, 374 * scale)

                Image("duckLoginHero")
                    .resizable()
                    .frame(width: proxy.size.width, height: 594 * scale)
                    .accessibilityHidden(true)

                Text("위고에 오신 것을\n환영해요!")
                    .wegoFont(.semibold, 30, tracking: -1.5, lineHeight: 45)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                    .padding(.top, 468 * scale)

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    buttons
                    terms
                }
            }
        }
        .ignoresSafeArea()
    }

    private var buttons: some View {
        VStack(spacing: 9) {
            SocialLoginButton(icon: "iconGoogle", title: "구글로 시작하기", style: .light) {
                appState.signIn(with: .google)
            }
            SocialLoginButton(icon: "iconApple", title: "Apple로 시작하기", style: .dark) {
                appState.signIn(with: .apple)
            }
            SocialLoginButton(icon: nil, title: "비로그인으로 시작하기", style: .light) {
                appState.continueAsGuest()
            }
        }
        .padding(.horizontal, 14)
    }

    private var terms: some View {
        Text("시작과 동시에 위고의 서비스 이용약관, 개인정보 수집 및 이용, 개인정보 위탁 제공에 동의하게 됩니다.")
            .wegoFont(.regular, 14, tracking: -0.7, lineHeight: 22)
            .foregroundStyle(WeGoColor.textCaption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 31)
            .padding(.bottom, 54)
    }
}

struct SocialLoginButton: View {
    enum Style {
        case light
        case dark
    }

    /// 없으면 글자만
    let icon: String?
    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(icon)
                }
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
