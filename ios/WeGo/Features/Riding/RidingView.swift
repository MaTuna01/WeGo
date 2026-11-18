import MapKit
import SwiftUI

/// 코스 안내 주행 (Figma 299:343): 지도(코스·지나온 경로, 오리 위치 표시) + 지도 버튼 + 일시정지 + 하단 패널.
/// 주행 중에는 하단 탭바를 숨긴다(MainView).
struct RidingView: View {
    @Environment(AppState.self) private var appState
    @Environment(LocationService.self) private var location
    let session: RideSession
    var farePolicy: any FarePolicy = TtareungyiFarePolicy()

    @State private var camera: MapCameraPosition = .userLocation(followsHeading: false, fallback: .region(MockData.defaultRegion))
    @State private var lastCamera: MapCamera?
    @State private var confirmStop = false

    /// 하단 패널 높이. 지도 버튼은 패널 위로 띄운다.
    private let panelHeight: CGFloat = 262

    var body: some View {
        ZStack(alignment: .topLeading) {
            RideMapView(session: session, heading: heading, position: $camera, lastCamera: $lastCamera)
                .ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                TimePassBadge(pass: session.pass, remaining: session.remainingPassTime(at: context.date))
            }
            .padding(.leading, 20)
            .padding(.top, 8)
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
                RidingPanel(
                    fare: farePolicy.overtimeFee(rentalElapsed: session.rentalElapsed(at: context.date), pass: session.pass),
                    ridingTime: session.ridingElapsed(at: context.date),
                    distanceMeters: session.distanceMeters,
                    isPaused: session.isPaused,
                    onStop: { confirmStop = true },
                    onTogglePause: { appState.togglePauseRide() }
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

/// 하단 패널. 왼쪽 "0원"은 시간권 초과 추가요금(예상), 가운데는 일시정지를 뺀 주행 시간.
struct RidingPanel: View {
    let fare: Int
    let ridingTime: TimeInterval
    let distanceMeters: Double
    let isPaused: Bool
    let onStop: () -> Void
    let onTogglePause: () -> Void

    var body: some View {
        BottomSheetContainer(showsHandle: false) {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    metric(value: WeGoFormat.won(fare), unit: "원", size: 40)
                        .accessibilityLabel("추가 요금 \(fare)원")
                    Spacer(minLength: 8)
                    Text(WeGoFormat.clock(ridingTime))
                        .wegoFont(.bold, 35, tracking: -0.7)
                        .monospacedDigit()
                        .foregroundStyle(isPaused ? WeGoColor.gray500 : .black)
                        .padding(.top, 4)
                        .accessibilityLabel("주행 시간 \(WeGoFormat.clock(ridingTime))")
                    Spacer(minLength: 8)
                    metric(value: WeGoFormat.kilometers(distanceMeters), unit: "km", size: 35)
                        .padding(.top, 4)
                        .accessibilityLabel("이동 거리 \(WeGoFormat.kilometers(distanceMeters))킬로미터")
                }
                .padding(.leading, 26)
                .padding(.trailing, 33)
                .padding(.top, 12)

                HStack(spacing: 20) {
                    panelButton("주행 그만하기", background: WeGoColor.chip, action: onStop)
                    panelButton(isPaused ? "다시 시작" : "일시정지", background: .black, action: onTogglePause)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)

                Spacer(minLength: 0)
            }
        }
    }

    private func metric(value: String, unit: String, size: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .wegoFont(.bold, size, tracking: -size * 0.02)
                .monospacedDigit()
                .foregroundStyle(.black)
            Text(unit)
                .wegoFont(.regular, 18, tracking: -0.36)
                .foregroundStyle(.black)
        }
    }

    private func panelButton(_ title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .wegoFont(.regular, 14, tracking: -0.7)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(background, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 왼쪽 위 흰 알약(Figma 143:447, 내용 미정) — 시간권 남은 시간을 보여준다.
struct TimePassBadge: View {
    let pass: TimePass
    let remaining: TimeInterval

    var body: some View {
        let isOver = remaining < 0
        Text(isOver ? "초과 \(WeGoFormat.minutesSeconds(remaining))" : "남은 \(WeGoFormat.minutesSeconds(remaining))")
            .wegoFont(.semibold, 14, tracking: -0.5)
            .monospacedDigit()
            .foregroundStyle(isOver ? WeGoColor.red : WeGoColor.gray900)
            .padding(.horizontal, 14)
            .frame(minWidth: 109, minHeight: 33)
            .background(.white, in: Capsule())
            .accessibilityLabel("\(pass.title) \(isOver ? "초과" : "남은 시간") \(WeGoFormat.minutesSeconds(remaining))")
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

#Preview("라이딩 패널") {
    RidingPanel(fare: 0, ridingTime: 2385, distanceMeters: 1000, isPaused: false, onStop: {}, onTogglePause: {})
        .frame(height: 262)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .background(Color.gray.opacity(0.3))
}
