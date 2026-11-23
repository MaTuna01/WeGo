import MapKit
import SwiftUI

/// 코스 안내 주행 지도 (Figma 299:343).
/// 코스 경로(연한 주황) 위에 지나온 경로(진한 주황)를 겹쳐 그리고, 출발·도착 정류장 핀과 오리 모양 내 위치를 보여준다.
struct RideMapView: View {
    @Environment(AppState.self) private var appState
    let session: RideSession
    /// 진행 방향(도, 북쪽 0·시계 방향). 모르면 nil
    let heading: Double?
    @Binding var position: MapCameraPosition
    /// 확대/축소 버튼이 쓰는 마지막 카메라 상태
    @Binding var lastCamera: MapCamera?

    var body: some View {
        Map(position: $position) {
            if let course = session.course, course.path.count > 1 {
                MapPolyline(coordinates: course.coordinates)
                    .stroke(WeGoColor.primaryLight.opacity(0.75), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }
            // 앱이 꺼져 있던 구간은 잇지 않고 구간마다 따로 그린다.
            ForEach(Array(session.trackSegments.enumerated()), id: \.offset) { _, segment in
                if segment.count > 1 {
                    MapPolyline(coordinates: segment)
                        .stroke(WeGoColor.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }

            Annotation(session.startStation.name, coordinate: session.startStation.coordinate, anchor: StationPin.anchor(isSelected: false)) {
                StationPin(isSelected: false)
            }
            .annotationTitles(.hidden)

            if let end = appState.stationRepository.station(id: session.course?.endStationID) {
                Annotation(end.name, coordinate: end.coordinate, anchor: StationPin.anchor(isSelected: false)) {
                    StationPin(isSelected: false)
                }
                .annotationTitles(.hidden)
            }

            UserAnnotation {
                RiderMarker(heading: heading)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {}
        .onMapCameraChange(frequency: .onEnd) { context in
            lastCamera = context.camera
        }
    }
}

/// 내 위치: 주황 후광 + 흰 원 + 하늘 모자 오리, 위쪽에 진행 방향 화살표 (Figma 299:363~365, 299:396)
struct RiderMarker: View {
    let heading: Double?

    var body: some View {
        ZStack {
            Circle()
                .fill(WeGoColor.primaryLight.opacity(0.3))
                .frame(width: 50, height: 50)
            Circle()
                .fill(.white)
                .frame(width: 36, height: 36)
            Image("duckSkyHat")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            if let heading {
                // 1) 화살표 축(홈 → 꼭짓점)이 북쪽을 향하도록 돌리고
                // 2) 꼭짓점이 원 중심 바로 위 tipRadius 지점에 오도록 옮긴 뒤
                // 3) 원 중심을 기준으로 진행 방향만큼 돌린다 → 원 중심과 꼭짓점을 잇는 선 = 진행 방향
                Image("headingArrow")
                    .rotationEffect(.radians(-HeadingArrow.axisAngle))
                    .offset(x: -HeadingArrow.rotatedTip.x, y: -HeadingArrow.tipRadius - HeadingArrow.rotatedTip.y)
                    .rotationEffect(.degrees(heading))
            }
        }
        .frame(width: 80, height: 80)
        .accessibilityLabel("내 위치")
    }
}

/// 진행 방향 화살표(headingArrow.svg, 16×16) 그림의 기하 정보.
/// 경로: (0,11) → 꼭짓점 (12,0) → (16,16) → 홈 (9,10.5). 그림 중심은 (8,8)이고 꼭짓점 축은 중심을 지나지 않는다.
private enum HeadingArrow {
    static let center = CGPoint(x: 8, y: 8)
    static let tip = CGPoint(x: 12, y: 0)
    static let notch = CGPoint(x: 9, y: 10.5)

    /// 원 중심에서 꼭짓점까지 거리. 화살표 몸통이 바깥 후광(반지름 25) 테두리에 걸치게 한다.
    static let tipRadius: CGFloat = 33

    /// 그림 속 화살표 축(홈 → 꼭짓점)이 북쪽에서 시계 방향으로 기운 각도(약 16°)
    static let axisAngle: Double = atan2(tip.x - notch.x, notch.y - tip.y)

    /// 그림을 -axisAngle 돌린 뒤, 그림 중심 기준 꼭짓점 위치(화면 좌표, 시계 방향 회전)
    static let rotatedTip: CGPoint = {
        let x = tip.x - center.x, y = tip.y - center.y
        let a = -axisAngle
        return CGPoint(x: x * cos(a) - y * sin(a), y: x * sin(a) + y * cos(a))
    }()
}

/// 오른쪽 원형 일시정지 버튼(60, Figma 299:397·398). 멈춘 동안은 다시 시작 아이콘
struct RidePauseButton: View {
    let isPaused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isPaused {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 2)
                } else {
                    Image("rideSideButtonIcon")
                }
            }
            .frame(width: 60, height: 60)
            .background(WeGoColor.buttonDark, in: Circle())
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPaused ? "주행 다시 시작" : "주행 일시정지")
    }
}
