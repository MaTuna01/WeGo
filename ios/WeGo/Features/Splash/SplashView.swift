import SwiftUI

/// 앱 실행 시 로딩 화면.
/// 시안이 두 가지라 둘 다 구현했다: 일러스트(Figma 143:342, 기본값) / 사진(Figma 143:448).
struct SplashView: View {
    enum Style {
        case illustration
        case photo
    }

    static var style: Style = .illustration

    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch Self.style {
            case .illustration: SplashIllustrationView()
            case .photo: SplashPhotoView()
            }
        }
        .task {
            // TODO: 정류장 목록(ETag) 캐시 갱신, 토큰 확인 등 실제 로딩 작업으로 교체
            try? await Task.sleep(for: .seconds(1.6))
            appState.finishSplash()
        }
    }
}

/// Figma 143:342 — 손글씨 "위고" 로고 + 헬멧 쓴 오리 일러스트
struct SplashIllustrationView: View {
    var body: some View {
        DesignCanvas {
            Image("splashLogoKo").offset(x: 109.44, y: 183.33)
            tagline
                .frame(width: 402)
                .offset(y: 283)
            Image("splashLine1").offset(x: 0.09, y: 644.77)
            Image("splashLine2").offset(x: -21.96, y: 498.49)
            Image("splashLine3").offset(x: 237.67, y: 409.95)
            Image("splashLine4").offset(x: -21.93, y: 596.76)
            DuckRiderImage(width: 327, height: 339).offset(x: 54, y: 336)
            Image("splashAccent1").offset(x: 170.5, y: 525.5)
            Image("splashAccent2").offset(x: 187.5, y: 524.5)
            Image("splashAccent3").offset(x: 164.5, y: 546.5)
        }
        .background(Color.white.ignoresSafeArea())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("위고. 오늘은 어디로 가볼까?")
    }

    private var tagline: some View {
        (Text("오늘은 ")
            + Text("어디로").foregroundStyle(WeGoColor.primaryLight)
            + Text(" 가볼까?"))
            .font(WeGoFont.pretendard(.medium, 22))
            .foregroundStyle(WeGoColor.textBody)
    }
}

/// Figma 143:448 — 한강 따릉이 사진 + WEGO 로고
struct SplashPhotoView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Image("splashPhoto")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                VStack(spacing: 13) {
                    Image("splashLogoWego")
                    Text("오늘은 어디로 가볼까?")
                        .wegoFont(.medium, 25)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.49), radius: 5)
                }
                .padding(.top, proxy.size.height * 196 / 874)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("위고. 오늘은 어디로 가볼까?")
    }
}

#Preview("일러스트") {
    SplashIllustrationView()
}

#Preview("사진") {
    SplashPhotoView()
}
