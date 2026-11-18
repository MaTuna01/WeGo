# WeGo iOS

SwiftUI · iOS 17+ · Xcode 16+ (폴더 동기화 그룹 사용 — `WeGo/` 안에 파일을 추가하면 Xcode에 자동 반영)

## 처음 실행

```sh
cd ios
open WeGo.xcodeproj                # 시뮬레이터(iPhone 17) 선택 후 ⌘R
```

- 에셋과 폰트는 이미 커밋돼 있어 받지 않아도 된다. 다시 받아야 하면 `sh scripts/fetch-figma-assets.sh`(Figma 에셋 24개 + Pretendard 폰트).
  스크립트의 Figma 에셋 URL은 2026-11-18에 만료됐으므로, 실행 전 URL을 갱신해 스크립트 표를 다시 채운다.
- `Assets.xcassets/Design/` 에셋은 스크립트가 아니라 디자이너가 Figma에서 내보낸 파일(`design-exports/`, gitignore)을 직접 등록한 것이다.
- 실기기 실행은 Signing & Capabilities에서 Team을 지정한다.
- 시뮬레이터 위치: Features ▸ Location ▸ Custom Location (여의나루 37.5271, 126.9329) 또는 City Bicycle Ride.

## 구조

```
WeGo/
  App/            앱 진입점, AppState(화면 단계·탭·라이딩 세션·지정 코스·10분 전 알림)
  Core/           모델·목업 데이터(코스·후기), 위치, 라이딩 세션(1초 간격 기록), 코스 진행 계산(CourseProgress),
                  10분 전 알림(RideReminder), Live Activity, 운영사 앱 열기·복귀 감지(RentalAppLauncher), 요금 정책
  DesignSystem/   색상·폰트 토큰, 공통 컴포넌트(탭바, 칩, 바텀시트, 캔버스)
  Features/       Splash · Login · Main · Home(지도/정류장 시트/코스 목록) · Course(코스 상세·경사도) · Riding · Profile
  Resources/      Assets.xcassets(Figma/는 스크립트가 생성, Design/은 내보낸 파일을 직접 등록), Fonts
RideWidget/       위젯 확장 타깃 — 라이딩 Live Activity(잠금화면·다이나믹 아일랜드)
Shared/           앱·위젯 두 타깃이 함께 컴파일하는 코드(RideActivityAttributes)
Config/           Info.plist는 배열·사전형 키만(UIAppFonts, UIBackgroundModes, 위젯 NSExtension). 나머지는 빌드 설정 INFOPLIST_KEY_*
```

## Figma ↔ 화면

`ios wireframe` 페이지의 299:* 프레임(왼쪽부터 화면 순서)이 기준이다.

| Figma 노드 | 화면 |
|---|---|
| 299:20 (143:342 / 143:448) | SplashView (일러스트 기본 / 사진 버전) |
| 299:38 | LoginView (구글 / Apple / 비로그인으로 시작하기) |
| 299:58 | HomeView + HomeSheet (많이 찾는 코스 / 나의 이용 기록) |
| 299:121 | HomeView + StationSheet (코스 목록 CourseRow, 지도에 선택 코스 경로), WeGoTabBar(299:210~213 아이콘) |
| 299:224 | CourseDetailView (경사도 ElevationChart, 코스 정보, 사용자 후기) |
| 299:343 | RidingView 코스 안내 주행 (RideMapView, RideReminderBar, RideCheerBanner, RideStatsPanel) |
| 299:457 | RideCancelCourseModal (코스 취소 확인) |
| 299:401 | RidingView 자유 주행 (코스 취소 후 또는 코스 없이 출발) |
| 80:509 | WeGoColor, WeGoFont |

## 라이선스

- 디자인 에셋(오리 일러스트, 스플래시 사진, 위고 로고 등)은 **무단 사용 금지**다. [ASSETS-LICENSE.md](ASSETS-LICENSE.md) 참고.
- Pretendard 폰트는 SIL OFL 1.1 — `WeGo/Resources/Fonts/OFL.txt`를 폰트와 함께 둔다(앱 번들에도 포함된다).

## 커밋하면 안 되는 파일

API 키(`Secrets.xcconfig`), `GoogleService-Info.plist`, 인증서(`*.p12`), 프로비저닝 프로파일(`*.mobileprovision`), `AuthKey_*.p8`는 `.gitignore`로 막아 두었다. 키가 필요하면 `Secrets.example.xcconfig`처럼 값을 비운 예시 파일만 올린다.
