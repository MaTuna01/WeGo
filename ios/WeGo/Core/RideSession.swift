import CoreLocation
import Foundation
import Observation

/// 진행 중인 라이딩 1건.
/// - 대여 시간(rentalElapsed): 일시정지와 무관하게 흐른다. 시간권 남은 시간·초과요금 계산에 쓴다.
/// - 주행 시간(ridingElapsed): 일시정지 구간을 뺀 시간. 큰 타이머에 보여준다.
@Observable
final class RideSession {
    let startStation: Station
    let pass: TimePass
    let startedAt: Date

    private(set) var isPaused = false
    private(set) var distanceMeters: CLLocationDistance = 0
    private(set) var track: [CLLocationCoordinate2D] = []

    @ObservationIgnored private var pausedAt: Date?
    @ObservationIgnored private var pausedTotal: TimeInterval = 0
    @ObservationIgnored private var lastLocation: CLLocation?

    init(startStation: Station, pass: TimePass, startedAt: Date = .now) {
        self.startStation = startStation
        self.pass = pass
        self.startedAt = startedAt
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
