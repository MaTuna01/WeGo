import CoreLocation
import Foundation
import Testing
@testable import WeGo

/// 진행 중 주행: 시간 계산, 거리 기록, 스냅샷 저장·복구(#21)
struct RideSessionTests {
    private let station = Fixtures.yeouinaru
    private let yeouinaru = Fixtures.yeouinaru.coordinate
    private let wonhyo = Fixtures.wonhyo.coordinate

    /// a → b 직선을 1초 간격·일정 속도로 달린 위치들
    private func ride(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D, steps: Int, start: Date, speed: Double = 5) -> [CLLocation] {
        Fixtures.line(a, b, steps: steps).enumerated().map { index, coordinate in
            Fixtures.location(coordinate, at: start.addingTimeInterval(Double(index)), speed: speed)
        }
    }

    // MARK: 시간

    @Test func 일시정지한_시간은_주행_시간에서_빠지고_대여_시간에는_남는다() {
        let now = Date()
        let session = RideSession(startStation: station, pass: .oneHour, startedAt: now.addingTimeInterval(-600))

        #expect(abs(session.ridingElapsed(at: now) - 600) < 1)

        session.togglePause() // 지금 멈춤
        let later = now.addingTimeInterval(120)
        #expect(session.isPaused)
        #expect(abs(session.ridingElapsed(at: later) - 600) < 1)
        #expect(abs(session.rentalElapsed(at: later) - 720) < 1)
        #expect(abs(session.remainingPassTime(at: later) - (3_600 - 720)) < 1)
    }

    @Test func 시간권이_끝나면_남은_시간이_음수다() {
        let now = Date()
        let session = RideSession(startStation: station, pass: .oneHour, startedAt: now.addingTimeInterval(-3_700))
        #expect(session.remainingPassTime(at: now) < 0)
    }

    // MARK: 거리 기록

    @Test func 달린_거리를_더한다() {
        let session = RideSession(startStation: station, pass: .oneHour)
        ride(from: yeouinaru, to: wonhyo, steps: 70, start: .now).forEach(session.record)

        #expect(session.trackPoints.count == 71)
        #expect(abs(session.distanceMeters - 705) < 10)
    }

    @Test func 멈춰_있을_때의_GPS_흔들림은_거리에_더하지_않는다() {
        let session = RideSession(startStation: station, pass: .oneHour)
        let start = Date()
        // 제자리에서 몇 m씩 흔들리는 위치(속도 0)
        let jitter = [(0.0, 0.0), (0.00003, 0.00002), (-0.00002, 0.00003), (0.00001, -0.00003), (0.0, 0.00001)]
        for (index, offset) in jitter.enumerated() {
            let coordinate = Fixtures.coordinate(yeouinaru.latitude + offset.0, yeouinaru.longitude + offset.1)
            session.record(Fixtures.location(coordinate, at: start.addingTimeInterval(Double(index)), speed: 0))
        }

        #expect(session.distanceMeters == 0)
        // 쉰 시간이 보이도록 점은 남긴다.
        #expect(session.trackPoints.count == jitter.count)
    }

    @Test func 정확도가_50m보다_나쁜_위치는_버린다() {
        let session = RideSession(startStation: station, pass: .oneHour)
        session.record(Fixtures.location(yeouinaru, at: .now, horizontalAccuracy: 80))
        session.record(Fixtures.location(yeouinaru, at: .now, horizontalAccuracy: -1))
        #expect(session.trackPoints.isEmpty)
    }

    @Test func 일시정지_중에는_기록하지_않는다() {
        let session = RideSession(startStation: station, pass: .oneHour)
        session.togglePause()
        ride(from: yeouinaru, to: wonhyo, steps: 10, start: .now).forEach(session.record)
        #expect(session.trackPoints.isEmpty)
        #expect(session.distanceMeters == 0)
    }

    // MARK: 스냅샷 저장·복구

    @Test func 복구하면_기록이_이어지고_꺼져_있던_구간은_끊는다() throws {
        let start = Date().addingTimeInterval(-300)
        let session = RideSession(startStation: station, pass: .oneHour, startedAt: start)
        let points = ride(from: yeouinaru, to: wonhyo, steps: 70, start: start)
        points[0...30].forEach(session.record)
        let distanceBefore = session.distanceMeters

        // 파일 저장과 같은 방식으로 직렬화했다 읽기
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let snapshot = try PropertyListDecoder().decode(RideSession.Snapshot.self, from: encoder.encode(session.snapshot))
        let restored = RideSession(restoring: snapshot, station: station, course: nil, initialCourse: nil)

        #expect(restored.startedAt == start)
        #expect(restored.trackPoints == session.trackPoints)
        #expect(restored.distanceMeters == distanceBefore)
        #expect(restored.segmentStarts == [31])

        // 앱이 꺼져 있던 동안(31~49) 위치가 없고, 50번째 점부터 다시 들어온다.
        points[50...70].forEach(restored.record)

        #expect(restored.trackSegments.count == 2)
        // 끊긴 사이 거리(약 190m)는 더하지 않는다. 복구 후 첫 점은 거리 기준점만 잡는다.
        let afterResume = restored.distanceMeters - distanceBefore
        #expect(afterResume < 220)
        #expect(afterResume > 180)
    }

    @Test func 복구해도_일시정지_상태와_코스_취소_여부가_남는다() {
        let course = MockData.courses[0]
        let session = RideSession(startStation: station, pass: .twoHours, course: course)
        session.cancelCourse()
        session.togglePause()

        let restored = RideSession(restoring: session.snapshot, station: station, course: nil, initialCourse: course)

        #expect(restored.isPaused)
        #expect(restored.pass == .twoHours)
        #expect(restored.course == nil)
        #expect(restored.initialCourse?.id == course.id)
    }

    // MARK: 구간 나누기

    @Test func 구간_시작_인덱스로_경로를_나눈다() {
        #expect(TrackSegments.split([1, 2, 3, 4, 5], at: [2, 4]) == [[1, 2], [3, 4], [5]])
        #expect(TrackSegments.split([1, 2, 3], at: []) == [[1, 2, 3]])
        #expect(TrackSegments.split([1, 2, 3], at: [0, 3, 9]) == [[1, 2, 3]])
        #expect(TrackSegments.split([Int](), at: [1]) == [])
    }
}
