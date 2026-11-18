import MapKit
import SwiftUI

/// 코스 안내 주행 (Figma 299:343): 지도(코스·지나온 경로, 오리 위치 표시) + 응원 배너 + 지도 버튼 + 일시정지 + 하단 패널.
/// 주행 중에는 하단 탭바를 숨긴다(MainView). 코스 없이 출발한 자유 주행도 같은 화면을 쓰고, 패널 내용만 다르다.
struct RidingView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationService.self) private var location
    let session: RideSession

    @State private var camera: MapCameraPosition = .userLocation(followsHeading: false, fallback: .region(MockData.defaultRegion))
    @State private var lastCamera: MapCamera?
    @State private var confirmStop = false

    /// 하단 패널 높이(Figma 299:343). 지도 버튼은 패널 위로 띄운다.
    private let panelHeight: CGFloat = 202
    /// 상단 "10분 전 알림 받기" 바(높이 47)가 들어갈 자리. 응원 배너는 그 아래에 둔다.
    private let topBarReserve: CGFloat = 8 + 47 + 14

    var body: some View {
        RideMapView(session: session, heading: heading, position: $camera, lastCamera: $lastCamera)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                RideCheerBanner()
                    .padding(.horizontal, 21)
                    .padding(.top, topBarReserve)
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
                        // TODO: 운영사 앱으로 반납 → 복귀 확인 → 종료. 그 전까지는 종료 확인만 띄운다.
                        onReturn: { confirmStop = true }
                    )
                }
                .frame(height: panelHeight)
            }
            .confirmationDialog("주행을 그만할까요?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("주행 그만하기", role: .destructive) {
                    appState.endRide()
                }
                Button("계속 달리기", role: .cancel) {}
            } message: {
                Text("반납은 \(session.startStation.bikeOperator.displayName) 앱에서 해 주세요.")
            }
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
