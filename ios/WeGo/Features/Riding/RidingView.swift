import MapKit
import SwiftUI

/// 코스 안내 주행 (Figma 299:343): 지도(코스·지나온 경로, 오리 위치 표시) + 응원 배너 + 지도 버튼 + 일시정지 + 하단 패널.
/// 주행 중에는 하단 탭바를 숨긴다(MainView). 코스 없이 출발한 자유 주행도 같은 화면을 쓰고, 패널 내용만 다르다.
struct RidingView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationService.self) private var location
    @Environment(\.openURL) private var openURL
    let session: RideSession

    @State private var camera: MapCameraPosition = .userLocation(followsHeading: false, fallback: .region(MockData.defaultRegion))
    @State private var lastCamera: MapCamera?
    /// 반납하러 운영사 앱에 가 있는 동안 true. 돌아오면 반납 확인을 띄운다.
    @State private var awaitingReturn = false
    @State private var showReturnPrompt = false

    /// 하단 패널 높이(Figma 299:343). 지도 버튼은 패널 위로 띄운다.
    private let panelHeight: CGFloat = 202
    var body: some View {
        @Bindable var appState = appState

        RideMapView(session: session, heading: heading, position: $camera, lastCamera: $lastCamera)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                // 위: "10분 전 알림 받기" 바(좌우 17), 그 아래 14pt 띄워 응원 배너(좌우 21)
                VStack(spacing: 14) {
                    RideReminderBar(isOn: $appState.isRideReminderEnabled)
                        .padding(.horizontal, 17)
                    RideCheerBanner()
                        .padding(.horizontal, 21)
                }
                .padding(.top, 8)
            }
            .alert("알림이 꺼져 있어요", isPresented: $appState.isReminderPermissionDenied) {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("닫기", role: .cancel) {}
            } message: {
                Text("10분 전 알림을 받으려면 설정에서 위고 알림을 허용해 주세요.")
            }
            .overlay(alignment: .bottomLeading) {
                RideMapControls(
                    onZoomIn: { zoom(by: 0.5) },
                    onZoomOut: { zoom(by: 2) },
                    onRecenter: { withAnimation { camera = .userLocation(followsHeading: false, fallback: .region(MockData.defaultRegion)) } }
                )
                .padding(.leading, 20)
                .padding(.bottom, panelHeight + 22)
            }
            .overlay(alignment: .bottomTrailing) {
                RidePauseButton(isPaused: session.isPaused) { appState.togglePauseRide() }
                    .padding(.trailing, 16)
                    .padding(.bottom, panelHeight + 26)
            }
            .overlay(alignment: .bottom) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    RideStatsPanel(
                        stats: stats(at: context.date),
                        isPaused: session.isPaused,
                        // TODO: 코스 취소 확인 모달 → 자유 주행 전환(다음 이슈)
                        onCancelCourse: session.isFollowingCourse ? {} : nil,
                        onReturn: goReturn
                    )
                }
                .frame(height: panelHeight)
            }
            .onReturnFromOperatorApp(isAwaiting: awaitingReturn) {
                showReturnPrompt = true
            }
            .alert("반납을 마쳤나요?", isPresented: $showReturnPrompt) {
                Button("반납 완료") {
                    awaitingReturn = false
                    appState.endRide()
                }
                Button("아직이에요", role: .cancel) {
                    awaitingReturn = false
                }
            } message: {
                Text("\(session.startStation.bikeOperator.displayName) 앱에서 반납했다면 반납 완료를 눌러 주세요. 주행 기록이 끝나요.")
            }
    }

    /// 반납하러가기: 운영사 앱을 열고, 돌아오면 반납 확인을 띄운다.
    private func goReturn() {
        awaitingReturn = true
        // 시뮬레이터처럼 다른 앱을 못 여는 환경에서는 바로 반납 확인을 띄운다.
        RentalAppLauncher.open(session.startStation.bikeOperator, using: openURL) { showReturnPrompt = true }
    }

    private func stats(at date: Date) -> RideStats {
        if let course = session.course {
            let snapshot = location.lastLocation.flatMap { CourseProgress(course: course).snapshot(at: $0.coordinate) }
            return .following(course, remainingSeconds: snapshot?.remainingSeconds)
        }
        return .free(
            distanceMeters: session.distanceMeters,
            ridingSeconds: session.ridingElapsed(at: date),
            remainingPassSeconds: session.remainingPassTime(at: date)
        )
    }

    /// 움직일 때 GPS가 주는 진행 방향. 멈춰 있으면 방향을 알 수 없어 화살표를 숨긴다.
    private var heading: Double? {
        guard let last = location.lastLocation, last.course >= 0, last.speed >= 0.5 else { return nil }
        return last.course
    }

    /// factor < 1이면 확대, > 1이면 축소
    private func zoom(by factor: Double) {
        let base = lastCamera ?? MapCamera(
            centerCoordinate: location.lastLocation?.coordinate ?? session.startStation.coordinate,
            distance: 1500
        )
        let distance = min(max(base.distance * factor, 200), 50_000)
        withAnimation {
            camera = .camera(MapCamera(centerCoordinate: base.centerCoordinate, distance: distance, heading: base.heading, pitch: 0))
        }
    }
}

/// 라이딩 탭인데 진행 중인 라이딩이 없을 때 (디자인 없음, 임시 화면)
struct RideIdleView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            DuckRiderImage(width: 200, height: 207)
            Text("정류장을 고르고 대여하면\n여기서 라이딩이 시작돼요")
                .wegoFont(.semibold, 20, tracking: -0.8, lineHeight: 30)
                .multilineTextAlignment(.center)
                .foregroundStyle(WeGoColor.gray900)
            Button {
                appState.selectedTab = .home
            } label: {
                Text("정류장 고르러 가기")
                    .wegoFont(.bold, 16)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .frame(height: 48)
                    .background(WeGoColor.buttonDark, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
    }
}
