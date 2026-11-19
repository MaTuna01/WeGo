import MapKit

/// 지도에 그릴 정류장 고르기. SwiftUI Map은 클러스터링이 없어서, 정류장이 수천 곳이면
/// 화면에 보이는 영역 근처만 그리고 개수도 제한한다.
enum StationMapFilter {
    /// 이보다 넓게 축소하면(위도 차 약 9km) 정류장을 그리지 않고 확대 안내를 띄운다.
    static let maxLatitudeSpan: CLLocationDegrees = 0.08
    /// 한 번에 그리는 최대 개수. 넘으면 화면 중심에서 가까운 순으로 자른다.
    static let maxCount = 300
    /// 보이는 영역 바깥으로 이만큼(영역 크기 대비) 더 그려서, 지도를 조금 움직일 때 핀이 늦게 나타나지 않게 한다.
    static let margin = 0.25

    struct Result: Equatable {
        let stations: [Station]
        /// 너무 넓게 축소해서 정류장을 그리지 않았음(선택된 정류장은 예외)
        let isZoomedOutTooFar: Bool
    }

    /// - selectedID: 고른 정류장은 영역, 개수와 상관없이 항상 넣는다.
    static func stations(
        _ all: [Station],
        in region: MKCoordinateRegion,
        selectedID: Station.ID? = nil,
        maxLatitudeSpan: CLLocationDegrees = maxLatitudeSpan,
        maxCount: Int = maxCount
    ) -> Result {
        let selected = selectedID.flatMap { id in all.first { $0.id == id } }

        guard region.span.latitudeDelta <= maxLatitudeSpan else {
            return Result(stations: selected.map { [$0] } ?? [], isZoomedOutTooFar: true)
        }

        let halfLat = region.span.latitudeDelta * (0.5 + margin)
        let halfLon = region.span.longitudeDelta * (0.5 + margin)
        let center = region.center
        var inside = all.filter { station in
            abs(station.latitude - center.latitude) <= halfLat && abs(station.longitude - center.longitude) <= halfLon
        }

        if inside.count > maxCount {
            // 경도 1도의 거리는 위도에 따라 줄어드므로 cos(위도)로 맞춰 가까운 순을 고른다.
            let scale = cos(center.latitude * .pi / 180)
            func distance(_ station: Station) -> Double {
                let dLat = station.latitude - center.latitude
                let dLon = (station.longitude - center.longitude) * scale
                return dLat * dLat + dLon * dLon
            }
            inside = Array(inside.sorted { distance($0) < distance($1) }.prefix(maxCount))
        }

        if let selected, !inside.contains(where: { $0.id == selected.id }) {
            inside.append(selected)
        }
        return Result(stations: inside, isZoomedOutTooFar: false)
    }
}
