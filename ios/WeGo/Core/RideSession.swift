import CoreLocation
import Foundation
import Observation

/// 진행 중인 라이딩 1건.
/// - 대여 시간(rentalElapsed): 일시정지와 무관하게 흐른다. 시간권 남은 시간·초과요금 계산에 쓴다.
/// - 주행 시간(ridingElapsed): 일시정지 구간을 뺀 시간. 큰 타이머에 보여준다.
/// - 코스(course): 코스 안내 주행이면 있고, 자유 주행이거나 중간에 취소하면 nil. 기록은 어느 쪽이든 똑같이 남는다.
/// - 경로 기록(trackPoints): GPS가 주는 위치(움직이는 동안 약 1초 간격)를 시각과 함께 모두 남긴다.
///   멈춰 있는 동안의 점도 남겨서 쉰 시간이 보이게 하고, GPS 흔들림은 거리 합산에서만 거른다.
@Observable
final class RideSession {
    let startStation: Station
    let pass: TimePass
    let startedAt: Date

    private(set) var course: Course?
    /// 출발할 때 안내받기로 한 코스. 중간에 코스를 취소해도 남는다(기록용).
    let initialCourse: Course?
    private(set) var isPaused = false
    private(set) var distanceMeters: CLLocationDistance = 0
    private(set) var trackPoints: [TrackPoint] = []
    /// 새 구간이 시작되는 `trackPoints` 인덱스(0 제외). 앱이 꺼졌다 복구되면 그 사이를 직선으로 잇지 않으려고 끊는다.
    private(set) var segmentStarts: [Int] = []

    /// 일시정지 중이면 멈춘 시각
    @ObservationIgnored private(set) var pausedAt: Date?
    @ObservationIgnored private var pausedTotal: TimeInterval = 0
    /// 거리를 마지막으로 더한 위치. 흔들림이 쌓이지 않게, 실제로 움직였다고 볼 때만 옮긴다.
    @ObservationIgnored private var distanceAnchor: CLLocation?

    init(startStation: Station, pass: TimePass, course: Course? = nil, startedAt: Date = .now) {
        self.startStation = startStation
        self.pass = pass
        self.course = course
        self.initialCourse = course
        self.startedAt = startedAt
    }

    var isFollowingCourse: Bool {
        course != nil
    }

    /// 코스 안내를 그만두고 자유 주행으로 바꾼다. 지금까지의 기록(거리·경로·시간)은 그대로 이어진다.
    func cancelCourse() {
        course = nil
    }

    /// 시간권이 끝나는 시각
    var passEndsAt: Date {
        startedAt.addingTimeInterval(pass.duration)
    }

    /// 주행 시간 타이머의 기준 시각. 이 시각부터 흐른 시간(일시정지 중이면 pausedAt까지)이 주행 시간이다.
    var ridingClockStart: Date {
        startedAt.addingTimeInterval(pausedTotal)
    }

    func rentalElapsed(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }

    func ridingElapsed(at date: Date) -> TimeInterval {
        let pausedNow = pausedAt.map { date.timeIntervalSince($0) } ?? 0
        return max(0, rentalElapsed(at: date) - pausedTotal - pausedNow)
    }

    /// 음수면 시간권 초과
    func remainingPassTime(at date: Date) -> TimeInterval {
        pass.duration - rentalElapsed(at: date)
    }

    func togglePause() {
        if let pausedAt {
            pausedTotal += Date().timeIntervalSince(pausedAt)
            self.pausedAt = nil
            isPaused = false
            distanceAnchor = nil // 재개 시 정지 중 이동분이 거리에 섞이지 않게
        } else {
            pausedAt = .now
            isPaused = true
        }
    }

    /// 지도에 그릴 지나온 경로
    var track: [CLLocationCoordinate2D] {
        trackPoints.map(\.coordinate)
    }

    /// 끊긴 곳(앱이 꺼져 있던 구간)을 기준으로 나눈 경로. 지도는 구간마다 따로 그린다.
    var trackSegments: [[CLLocationCoordinate2D]] {
        TrackSegments.split(trackPoints.map(\.coordinate), at: segmentStarts)
    }

    func record(_ location: CLLocation) {
        guard !isPaused,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= Self.maxAccuracy else { return }

        trackPoints.append(TrackPoint(location))

        guard let anchor = distanceAnchor else {
            distanceAnchor = location
            return
        }
        let delta = location.distance(from: anchor)
        guard Self.isMoving(delta: delta, location: location) else { return }
        distanceMeters += delta
        distanceAnchor = location
    }

    /// 이보다 부정확한 위치는 기록하지 않는다(m)
    private static let maxAccuracy: CLLocationAccuracy = 50

    /// 실제로 움직였는지 판단한다. 멈춰 있어도 GPS 위치는 몇 m씩 흔들리므로,
    /// 속도 정보가 있으면 걷는 속도의 절반(0.5m/s) 이상일 때만, 없으면 정확도보다 멀리 갔을 때만 거리로 친다.
    private static func isMoving(delta: CLLocationDistance, location: CLLocation) -> Bool {
        guard delta >= 3 else { return false }
        if location.speed >= 0 {
            return location.speed >= 0.5
        }
        return delta > location.horizontalAccuracy
    }
}

// MARK: - 진행 중 주행 저장·복구

extension RideSession {
    /// 앱이 꺼져도 이어서 기록할 수 있게 저장하는 진행 중 주행 상태
    struct Snapshot: Codable {
        var startStationID: String
        var passIsTwoHours: Bool
        var startedAt: Date
        var courseID: String?
        var initialCourseID: String?
        var pausedAt: Date?
        var pausedTotal: TimeInterval
        var distanceMeters: Double
        var trackPoints: [TrackPoint]
        var segmentStarts: [Int]
    }

    var snapshot: Snapshot {
        Snapshot(
            startStationID: startStation.id,
            passIsTwoHours: pass == .twoHours,
            startedAt: startedAt,
            courseID: course?.id,
            initialCourseID: initialCourse?.id,
            pausedAt: pausedAt,
            pausedTotal: pausedTotal,
            distanceMeters: distanceMeters,
            trackPoints: trackPoints,
            segmentStarts: segmentStarts
        )
    }

    /// 저장해 둔 상태로 주행을 되살린다. 정류장·코스는 목록에서 찾아 넣어 준다.
    /// 앱이 꺼져 있던 동안은 위치가 없으므로, 다음 점부터 새 구간으로 시작하고 그 사이 거리는 더하지 않는다.
    convenience init(restoring snapshot: Snapshot, station: Station, course: Course?, initialCourse: Course?) {
        self.init(
            startStation: station,
            pass: snapshot.passIsTwoHours ? .twoHours : .oneHour,
            course: initialCourse,
            startedAt: snapshot.startedAt
        )
        self.course = course
        pausedAt = snapshot.pausedAt
        isPaused = snapshot.pausedAt != nil
        pausedTotal = snapshot.pausedTotal
        distanceMeters = snapshot.distanceMeters
        trackPoints = snapshot.trackPoints
        segmentStarts = snapshot.segmentStarts
        if !trackPoints.isEmpty, segmentStarts.last != trackPoints.count {
            segmentStarts.append(trackPoints.count)
        }
    }
}

enum TrackSegments {
    /// 좌표 목록을 구간 시작 인덱스에서 나눈다. 점이 하나뿐인 구간도 그대로 둔다.
    static func split<T>(_ items: [T], at starts: [Int]) -> [[T]] {
        guard !items.isEmpty else { return [] }
        var result: [[T]] = []
        var lower = 0
        for start in starts.sorted() where start > lower && start < items.count {
            result.append(Array(items[lower..<start]))
            lower = start
        }
        result.append(Array(items[lower...]))
        return result
    }
}

/// 주행 경로의 점 하나. 서버에 올릴 때는 시각을 M 값으로 담는다(LINESTRING M, 노션 5-2).
struct TrackPoint: Hashable, Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    /// m/s. 알 수 없으면 nil
    let speed: Double?
    /// m
    let horizontalAccuracy: Double

    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        timestamp = location.timestamp
        speed = location.speed >= 0 ? location.speed : nil
        horizontalAccuracy = location.horizontalAccuracy
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
