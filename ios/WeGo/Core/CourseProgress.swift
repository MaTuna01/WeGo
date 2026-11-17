import CoreLocation

/// 코스 안내 주행 중 "얼마나 왔고 얼마나 남았나"를 계산한다.
///
/// 현재 위치를 코스 선 위의 가장 가까운 점으로 옮겨(투영) 그 지점까지의 거리를 진행 거리로 본다.
/// 정류장 사이 몇 km 수준이라 지구 곡률은 무시하고, 위도 기준 평면 좌표(m)로 계산한다.
struct CourseProgress {
    struct Snapshot: Equatable {
        /// 출발점부터 코스를 따라 온 거리
        let traveledMeters: Double
        /// 코스를 따라 도착점까지 남은 거리
        let remainingMeters: Double
        /// 남은 예상 시간. 코스 예상 시간의 평균 속도로 환산한다(화면에는 "약 N분").
        let remainingSeconds: Double
        /// 현재 위치가 코스 선에서 떨어진 거리(경로 이탈 판단용)
        let offRouteMeters: Double
        /// 0...1
        let fraction: Double
    }

    let course: Course
    /// 각 경로 점까지의 누적 거리(m). 첫 값은 0
    private let cumulativeMeters: [Double]

    init(course: Course) {
        self.course = course
        var cumulative: [Double] = [0]
        for (a, b) in zip(course.path, course.path.dropFirst()) {
            cumulative.append(cumulative[cumulative.count - 1] + Self.distance(a.coordinate, b.coordinate))
        }
        cumulativeMeters = cumulative
    }

    var totalMeters: Double {
        cumulativeMeters.last ?? 0
    }

    /// 경로 점이 2개 미만이면 nil
    func snapshot(at location: CLLocationCoordinate2D) -> Snapshot? {
        let path = course.path
        guard path.count >= 2, totalMeters > 0 else { return nil }

        let origin = location
        let here = PlanePoint.zero
        var best: (traveled: Double, offRoute: Double)?

        for index in 0..<(path.count - 1) {
            let a = PlanePoint(path[index].coordinate, origin: origin)
            let b = PlanePoint(path[index + 1].coordinate, origin: origin)
            let segment = b - a
            let lengthSquared = segment.dot(segment)
            let t = lengthSquared > 0 ? min(max((here - a).dot(segment) / lengthSquared, 0), 1) : 0
            let projected = a + segment * t
            let offRoute = (here - projected).length
            if best == nil || offRoute < best!.offRoute {
                let segmentMeters = cumulativeMeters[index + 1] - cumulativeMeters[index]
                best = (cumulativeMeters[index] + segmentMeters * t, offRoute)
            }
        }

        guard let best else { return nil }
        let remaining = max(0, totalMeters - best.traveled)
        let metersPerSecond = course.durationSeconds > 0 ? totalMeters / Double(course.durationSeconds) : 0
        return Snapshot(
            traveledMeters: best.traveled,
            remainingMeters: remaining,
            remainingSeconds: metersPerSecond > 0 ? remaining / metersPerSecond : 0,
            offRouteMeters: best.offRoute,
            fraction: best.traveled / totalMeters
        )
    }

    /// 경사도 그래프용: 출발점부터의 거리별 고도. 고도가 없는 점은 건너뛴다.
    var elevationProfile: [ElevationSample] {
        zip(course.path, cumulativeMeters).compactMap { point, meters in
            point.elevationMeters.map { ElevationSample(distanceMeters: meters, elevationMeters: $0) }
        }
    }

    /// 경로 점 인덱스의 출발점부터 거리(경유 지점·자전거도로 구간을 그래프에 표시할 때)
    func distance(toPathIndex index: Int) -> Double {
        cumulativeMeters[min(max(index, 0), cumulativeMeters.count - 1)]
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

struct ElevationSample: Hashable {
    let distanceMeters: Double
    let elevationMeters: Double
}

/// 기준점(현재 위치) 근처를 평면으로 펼친 좌표(m)
private struct PlanePoint {
    var x: Double
    var y: Double

    static let zero = PlanePoint(x: 0, y: 0)
    private static let metersPerDegreeLatitude = 111_320.0

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    init(_ coordinate: CLLocationCoordinate2D, origin: CLLocationCoordinate2D) {
        let metersPerDegreeLongitude = Self.metersPerDegreeLatitude * cos(origin.latitude * .pi / 180)
        x = (coordinate.longitude - origin.longitude) * metersPerDegreeLongitude
        y = (coordinate.latitude - origin.latitude) * Self.metersPerDegreeLatitude
    }

    static func + (lhs: PlanePoint, rhs: PlanePoint) -> PlanePoint { PlanePoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    static func - (lhs: PlanePoint, rhs: PlanePoint) -> PlanePoint { PlanePoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    static func * (lhs: PlanePoint, rhs: Double) -> PlanePoint { PlanePoint(x: lhs.x * rhs, y: lhs.y * rhs) }
    func dot(_ other: PlanePoint) -> Double { x * other.x + y * other.y }
    var length: Double { dot(self).squareRoot() }
}
