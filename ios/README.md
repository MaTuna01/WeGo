# WeGo iOS

SwiftUI · iOS 17+ · Xcode 16+ (폴더 동기화 그룹 사용 — `WeGo/` 안에 파일을 추가하면 Xcode에 자동 반영)

## 처음 실행

```sh
cd ios
sh scripts/fetch-figma-assets.sh   # Figma 에셋 34개 + Pretendard 폰트 내려받기
open WeGo.xcodeproj                # 시뮬레이터(iPhone 17) 선택 후 ⌘R
```

- Figma 에셋 URL은 2026-11-18경 만료된다. 실패하면 URL을 갱신해 스크립트 표를 다시 채운다.
- 실기기 실행은 Signing & Capabilities에서 Team을 지정한다.
- 시뮬레이터 위치: Features ▸ Location ▸ Custom Location (여의나루 37.5271, 126.9329) 또는 City Bicycle Ride.

## 구조

```
WeGo/
  App/            앱 진입점, AppState(화면 단계·탭·라이딩 세션)
  Core/           모델, 목업 데이터, 위치, 라이딩 세션, 요금 정책, 대여 앱 열기
  DesignSystem/   색상·폰트 토큰, 공통 컴포넌트(탭바, 칩, 바텀시트, 캔버스)
  Features/       Splash · Login · Main · Home(지도/정류장) · Riding · Profile
  Resources/      Assets.xcassets(Figma 폴더는 스크립트가 생성), Fonts
RideWidget/       위젯 확장 타깃 — 라이딩 Live Activity(잠금화면·다이나믹 아일랜드)
Shared/           앱·위젯 두 타깃이 함께 컴파일하는 코드(RideActivityAttributes)
Config/           Info.plist는 배열·사전형 키만(UIAppFonts, UIBackgroundModes, 위젯 NSExtension). 나머지는 빌드 설정 INFOPLIST_KEY_*
```

## Figma ↔ 화면

| Figma 노드 | 화면 |
|---|---|
| 143:342 / 143:448 | SplashView (일러스트 기본 / 사진 버전) |
| 143:386 | LoginView |
| 143:528 | HomeView + HomeSheet |
| 143:458 | HomeView + StationSheet (정류장 선택) |
| 143:420 | RidingView |
| 80:509 | WeGoColor, WeGoFont, WeGoTabBar |

## 라이선스

- 디자인 에셋(오리 일러스트, 스플래시 사진, 위고 로고 등)은 **무단 사용 금지**다. [ASSETS-LICENSE.md](ASSETS-LICENSE.md) 참고.
- Pretendard 폰트는 SIL OFL 1.1 — `WeGo/Resources/Fonts/OFL.txt`를 폰트와 함께 둔다(앱 번들에도 포함된다).

## 커밋하면 안 되는 파일

API 키(`Secrets.xcconfig`), `GoogleService-Info.plist`, 인증서(`*.p12`), 프로비저닝 프로파일(`*.mobileprovision`), `AuthKey_*.p8`는 `.gitignore`로 막아 두었다. 키가 필요하면 `Secrets.example.xcconfig`처럼 값을 비운 예시 파일만 올린다.
