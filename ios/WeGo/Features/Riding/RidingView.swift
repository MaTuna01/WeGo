import MapKit
import SwiftUI

/// 라이딩 중 (Figma 143:420): 지도 + 하단 패널(추가요금 · 주행 시간 · 거리, 주행 그만하기 / 일시정지)
struct RidingView: View {
    @Environment(AppState.self) private var appState
    let session: RideSession
    var farePolicy: any FarePolicy = TtareungyiFarePolicy()

    @State private var camera: MapCameraPosition = .userLocation(followsHeading: false, fallback: .region(MockData.defaultRegion))
    @State private var confirmStop = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $camera) {
                UserAnnotation {
                    CurrentLocationMarker()
                }
                if session.track.count > 1 {
                    MapPolyline(coordinates: session.track)
                        .stroke(WeGoColor.primary, lineWidth: 5)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                TimePassBadge(pass: session.pass, remaining: session.remainingPassTime(at: context.date))
            }
            .padding(.leading, 20)
            .padding(.top, 8)
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
            .frame(height: 262)
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
