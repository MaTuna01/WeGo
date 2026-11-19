import SwiftUI

/// 시작 화면 (Figma 299:38): 상단 오리 일러스트, 환영 문구, 시작하기.
/// 1.0은 로그인 없이 쓰므로(노션 "앱 개발" 1.0 출시 계획) 구글/Apple 버튼은 빼고 시작하기 하나만 둔다.
/// 소셜 로그인은 서버 연동(1.1) 때 다시 넣는다. 그때 쓸 SocialLoginButton과 AppState.signIn은 남겨 둔다.
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
        SocialLoginButton(icon: nil, title: "시작하기", style: .dark) {
            appState.continueAsGuest()
        }
        .padding(.horizontal, 14)
    }

    /// 1.0의 실제 동작만 안내한다(서버로 보내는 정보가 없고, 약관/위탁 제공도 없음).
    private var terms: some View {
        Text("위치 정보는 주행 경로 기록에만 쓰고, 기록은 이 기기에만 저장돼요.")
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
