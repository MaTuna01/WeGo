import MapKit
import SwiftUI

/// 정류장 지도. 핀을 누르면 선택되고, 빈 곳을 누르면 선택이 풀린다.
/// TODO: 서울 정류장 ~2,700개를 다 띄우면 무거우므로 줌 레벨별 클러스터링 필요.
/// (기획상 네이버/카카오 지도 SDK도 후보 — MVP 화면 검증은 MapKit으로 먼저 한다.)
struct StationMapView: View {
    let stations: [Station]
    @Binding var selectedID: Station.ID?
    @Binding var position: MapCameraPosition

    var body: some View {
        Map(position: $position, selection: $selectedID) {
            UserAnnotation {
                CurrentLocationMarker()
            }
            ForEach(stations) { station in
                let isSelected = station.id == selectedID
                Annotation(station.name, coordinate: station.coordinate, anchor: StationPin.anchor(isSelected: isSelected)) {
                    StationPin(isSelected: isSelected)
                }
                .annotationTitles(.hidden)
                .tag(station.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }
}

/// 정류장 핀 (기본: Figma 143:487 + 143:488 / 선택: 143:500 + 143:502 + 143:503)
struct StationPin: View {
    let isSelected: Bool

    /// 핀 끝이 좌표에 오도록 하는 기준점 (핀 아래 자전거 배지는 좌표보다 아래에 그려진다)
    static func anchor(isSelected: Bool) -> UnitPoint {
        isSelected ? UnitPoint(x: 0.5, y: 72.0 / 97.0) : UnitPoint(x: 0.5, y: 37.0 / 58.0)
    }

    var body: some View {
        if isSelected {
            ZStack(alignment: .topLeading) {
                Image("pinStationSelected")
                Image("pinSelectedBadge").offset(x: 19, y: 79)
                Image("pinSelectedBike").offset(x: 21.5, y: 83.5)
            }
            .frame(width: 54, height: 97, alignment: .topLeading)
        } else {
            ZStack(alignment: .topLeading) {
                Image("pinStation")
                Image("pinBikeBadge").offset(x: 7.5, y: 45.5)
            }
            .frame(width: 27, height: 58, alignment: .topLeading)
        }
    }
}

/// 내 위치 표시 (Figma 143:482~485: 후광 + 방향 삼각형 + 링 + 점)
struct CurrentLocationMarker: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("locHalo")
            Image("locHeading")
                .frame(width: 12, height: 22)
                .rotationEffect(.degrees(-90))
                .offset(x: 2, y: 8)
            Image("locRing").offset(x: 9, y: 9)
            Image("locDot").offset(x: 12, y: 12)
        }
        .frame(width: 36, height: 36, alignment: .topLeading)
        .accessibilityLabel("내 위치")
    }
}

/// 지도 상단: 검색바 자리(선택한 정류장 이름) + 내 위치 버튼 + 운영사 필터 칩
/// 와이어프레임의 칩 3개는 내용이 비어 있어 운영사 필터(전체/따릉이/타슈)로 채웠다.
struct MapTopBar: View {
    let title: String?
    @Binding var operatorFilter: BikeOperator?
    let onClear: () -> Void
    let onRecenter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                titleField
                Button(action: onRecenter) {
                    ZStack(alignment: .topLeading) {
                        Image("mapButtonBg")
                        Image("mapButtonIcon").offset(x: 12, y: 12)
                    }
                    .frame(width: 44, height: 44, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("내 위치로 이동")
            }
            HStack(spacing: 17) {
                PillChip(title: "전체", isSelected: operatorFilter == nil, width: 90) {
                    operatorFilter = nil
                }
                ForEach(BikeOperator.allCases, id: \.self) { bikeOperator in
                    PillChip(title: bikeOperator.displayName, isSelected: operatorFilter == bikeOperator, width: 90) {
                        operatorFilter = bikeOperator
                    }
                }
            }
        }
    }

    private var titleField: some View {
        HStack(spacing: 8) {
            Text(title ?? "지도에서 출발 정류장을 골라 주세요")
                .wegoFont(title == nil ? .regular : .semibold, 15, tracking: -0.5)
                .foregroundStyle(title == nil ? WeGoColor.gray500 : WeGoColor.gray900)
                .lineLimit(1)
            Spacer(minLength: 0)
            if title != nil {
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WeGoColor.gray500)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("선택 해제")
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(WeGoColor.surface, in: Capsule())
    }
}
