import CoreLocation

/// 주행 경로의 시작·끝을 정류장에 매칭하고, 정류장에서 정류장까지의 공유 가능 구간을 판정한다(노션 "기능 구현 방안 검토" 10-3).
///
/// - 출발 정류장: 경로 앞쪽에서 처음으로 매칭 반경 안에 들어온 정류장. 그 점이 공유 구간의 시작이다.
/// - 도착 정류장: 경로 뒤쪽에서 마지막으로 매칭 반경 안에 있던 정류장. 그 점이 공유 구간의 끝이다.
/// - 그 앞뒤(정류장 밖, 예: 집 앞)는 잘라내 공유하지 않는다. 출발 = 도착(같은 정류장으로 돌아온 주행)도 허용한다.
/// - 출발·도착 중 하나라도 매칭되지 않거나, 공유 구간의 실제 경로 길이가 최소 길이보다 짧으면 공유할 수 없다.
///   이때 도착 정류장은 비운다(정류장 밖에서 끝난 주행은 뒤쪽 검색이 출발 정류장으로 되돌아오기 때문).
///
/// 서버 연동 후에는 서버(POST /rides)가 다시 판정한다. 앱 판정은 기기 안에서 바로 보여주기 위한 값이다.
enum StationMatcher {
    /// 정류장 매칭 반경(m). 경로의 점과 정류장 사이 거리 기준이며, 정류장끼리의 거리와는 상관없다.
    static let matchRadius: CLLocationDistance = 100
    /// 최소 공유 경로 길이(m). 잘라낸 뒤 실제로 달린 경로가 이보다 짧으면 공유하지 않는다(대여 직후 바로 반납 등).
    static let minimumSharedLength: CLLocationDistance = 100

    struct Result: Equatable {
        /// 매칭된 출발·도착 정류장 ID(없으면 nil)
        var startStationID: String?
        var endStationID: String?
        /// 공유 구간의 첫 점·마지막 점 인덱스(포함). 둘 다 매칭됐을 때만 있다.
        var sharedRange: ClosedRange<Int>?
        /// 공유 구간을 실제로 달린 길이(m). 앱이 꺼져 끊긴 구간 사이는 더하지 않는다.
        var sharedLengthMeters: CLLocationDistance
        var isShareable: Bool

        static let unmatched = Result(startStationID: nil, endStationID: nil, sharedRange: nil, sharedLengthMeters: 0, isShareable: false)
    }

    /// - points: 주행 경로 점(시간 순)
    /// - segmentStarts: 경로가 끊긴 곳(새 구간이 시작되는 인덱스). 그 앞 점과의 거리는 더하지 않는다.
    static func match(
        points: [CLLocationCoordinate2D],
        segmentStarts: [Int] = [],
        stations: [Station],
        radius: CLLocationDistance = matchRadius,
        minimumLength: CLLocationDistance = minimumSharedLength
    ) -> Result {
        guard !points.isEmpty else { return .unmatched }
        let candidates = nearbyStations(stations, around: points, radius: radius)
        guard !candidates.isEmpty else { return .unmatched }

        let start = points.indices.lazy.compactMap { index in
            nearestStation(to: points[index], in: candidates, within: radius).map { (index, $0) }
        }.first
        let end = points.indices.reversed().lazy.compactMap { index in
            nearestStation(to: points[index], in: candidates, within: radius).map { (index, $0) }
        }.first

        guard let start, let end, start.0 <= end.0 else {
            return Result(
                startStationID: start?.1.id,
                endStationID: end?.1.id,
                sharedRange: nil,
                sharedLengthMeters: 0,
                isShareable: false
            )
        }

        let (startIndex, startStation) = start
        let (endIndex, endStation) = end
        let length = pathLength(points, from: startIndex, to: endIndex, segmentStarts: Set(segmentStarts))
        guard length >= minimumLength else {
            // 정류장 밖(예: 집 앞)에서 끝나면 뒤쪽에서 찾은 정류장이 출발 정류장 근처로 되돌아온다.
            // 이때 "출발 → 출발"로 보이지 않게 도착은 비운다.
            return Result(startStationID: startStation.id, endStationID: nil, sharedRange: nil, sharedLengthMeters: length, isShareable: false)
        }
        return Result(
            startStationID: startStation.id,
            endStationID: endStation.id,
            sharedRange: startIndex...endIndex,
            sharedLengthMeters: length,
            isShareable: true
        )
    }

    /// 점에서 반경 안의 가장 가까운 정류장
    static func nearestStation(
        to point: CLLocationCoordinate2D,
        in stations: [Station],
        within radius: CLLocationDistance
    ) -> Station? {
        let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
        var best: (station: Station, distance: CLLocationDistance)?
        for station in stations {
            let distance = location.distance(from: CLLocation(latitude: station.latitude, longitude: station.longitude))
            if distance <= radius, distance < (best?.distance ?? .infinity) {
                best = (station, distance)
            }
        }
        return best?.station
    }

    /// 경로를 감싸는 사각형(반경만큼 넓힘) 안의 정류장만 남긴다. 정류장이 수천 개여도 점마다 전부 비교하지 않게 한다.
    private static func nearbyStations(
        _ stations: [Station],
        around points: [CLLocationCoordinate2D],
        radius: CLLocationDistance
    ) -> [Station] {
        var minLat = points[0].latitude, maxLat = minLat
        var minLon = points[0].longitude, maxLon = minLon
        for point in points {
            minLat = min(minLat, point.latitude); maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude); maxLon = max(maxLon, point.longitude)
        }
        // 위도 1도 ≈ 111km. 경도는 위도에 따라 줄어드므로 cos(위도)로 나눈다(여유 있게 1.2배).
        let latMargin = radius / 111_000 * 1.2
        let lonMargin = latMargin / max(cos(maxLat * .pi / 180), 0.1)
        return stations.filter {
            $0.latitude >= minLat - latMargin && $0.latitude <= maxLat + latMargin &&
            $0.longitude >= minLon - lonMargin && $0.longitude <= maxLon + lonMargin
        }
    }

    /// from~to 사이 실제 경로 길이. 끊긴 곳(segmentStarts)의 앞뒤 점 사이는 건너뛴다.
    private static func pathLength(
        _ points: [CLLocationCoordinate2D],
        from: Int,
        to: Int,
        segmentStarts: Set<Int>
    ) -> CLLocationDistance {
        guard from < to else { return 0 }
        var total: CLLocationDistance = 0
        for index in (from + 1)...to where !segmentStarts.contains(index) {
            let a = CLLocation(latitude: points[index - 1].latitude, longitude: points[index - 1].longitude)
            let b = CLLocation(latitude: points[index].latitude, longitude: points[index].longitude)
            total += b.distance(from: a)
        }
        return total
    }
}
