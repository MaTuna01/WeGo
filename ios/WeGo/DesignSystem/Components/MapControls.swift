import MapKit
import SwiftUI

/// 지도 버튼 묶음: 확대/축소(36x72)와 현재 위치로 이동(36).
/// 주행 화면은 왼쪽(Figma 299:352~358), 홈 지도는 오른쪽(Figma 430:1942)에 둔다.
struct MapControls: View {
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onRecenter: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            VStack(spacing: 0) {
                controlButton(systemName: "plus", label: "지도 확대", action: onZoomIn)
                Rectangle()
                    .fill(WeGoColor.border)
                    .frame(width: 36, height: 1)
                controlButton(systemName: "minus", label: "지도 축소", action: onZoomOut)
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button(action: onRecenter) {
                Image(systemName: "scope")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("현재 위치로 이동")
        }
        .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
    }

    private func controlButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 35)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 확대/축소 버튼으로 바꿀 지도 영역 계산
enum MapZoom {
    /// 가장 많이 확대했을 때의 위도 차(약 200m)
    static let minLatitudeSpan: CLLocationDegrees = 0.002
    /// 가장 많이 축소했을 때의 위도 차(약 55km). 정류장은 StationMapFilter.maxLatitudeSpan보다 넓으면 그리지 않는다.
    static let maxLatitudeSpan: CLLocationDegrees = 0.5

    /// 가운데는 그대로 두고 영역 크기만 factor배로 바꾼다(0.5면 2배 확대, 2면 2배 축소).
    static func region(_ region: MKCoordinateRegion, scaledBy factor: Double) -> MKCoordinateRegion {
        let latitude = min(max(region.span.latitudeDelta * factor, minLatitudeSpan), maxLatitudeSpan)
        let ratio = region.span.latitudeDelta > 0 ? latitude / region.span.latitudeDelta : 1
        return MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(latitudeDelta: latitude, longitudeDelta: region.span.longitudeDelta * ratio)
        )
    }

    /// 시트와 상단 바에 가리지 않는 지도 영역의 가운데에 coordinate가 오도록 하는 영역.
    /// `visibleTop`, `visibleBottom`은 지도 높이에 대한 비율(0 = 맨 위)이다. 영역 크기(span)는 그대로 둔다.
    static func region(
        centering coordinate: CLLocationCoordinate2D,
        span: MKCoordinateSpan,
        visibleTop: Double,
        visibleBottom: Double
    ) -> MKCoordinateRegion {
        let visibleCenter = (visibleTop + visibleBottom) / 2
        // 보이는 영역의 가운데가 지도 가운데보다 위에 있으면, 그만큼 지도 중심을 남쪽으로 옮긴다.
        let centerLatitude = coordinate.latitude - (0.5 - visibleCenter) * span.latitudeDelta
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: coordinate.longitude),
            span: span
        )
    }
}
