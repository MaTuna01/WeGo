import CoreLocation
import Foundation
import Observation

/// 진행 중인 라이딩 1건.
/// - 대여 시간(rentalElapsed): 일시정지와 무관하게 흐른다. 시간권 남은 시간·초과요금 계산에 쓴다.
/// - 주행 시간(ridingElapsed): 일시정지 구간을 뺀 시간. 큰 타이머에 보여준다.
/// - 코스(course): 코스 안내 주행이면 있고, 자유 주행이거나 중간에 취소하면 nil. 기록은 어느 쪽이든 똑같이 남는다.
@Observable
final class RideSession {
    let startStation: Station
    let pass: TimePass
    let startedAt: Date

    private(set) var course: Course?
    private(set) var isPaused = false
    private(set) var distanceMeters: CLLocationDistance = 0
    private(set) var track: [CLLocationCoordinate2D] = []

    /// 일시정지 중이면 멈춘 시각
    @ObservationIgnored private(set) var pausedAt: Date?
    @ObservationIgnored private var pausedTotal: TimeInterval = 0
    @ObservationIgnored private var lastLocation: CLLocation?

    init(startStation: Station, pass: TimePass, course: Course? = nil, startedAt: Date = .now) {
        self.startStation = startStation
        self.pass = pass
        self.course = course
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
            lastLocation = nil // 재개 시 정지 중 이동분이 거리에 섞이지 않게
        } else {
            pausedAt = .now
            isPaused = true
        }
    }

    func record(_ location: CLLocation) {
        guard !isPaused,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 50 else { return }
        if let lastLocation {
            let delta = location.distance(from: lastLocation)
            guard delta >= 3 else { return } // GPS 떨림 무시
            distanceMeters += delta
        }
        lastLocation = location
        track.append(location.coordinate)
    }
}
