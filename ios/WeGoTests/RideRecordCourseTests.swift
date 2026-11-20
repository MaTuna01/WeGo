import CoreLocation
import Foundation
import Testing
@testable import WeGo

/// 주행 기록 → 정류장 시트 코스 변환(#25). RideRecord는 SwiftData 저장소 없이 메모리에서 만든다.
struct RideRecordCourseTests {
    private let yeouinaru = Fixtures.yeouinaru.coordinate
    private let wonhyo = Fixtures.wonhyo.coordinate

    /// 여러 직선을 1초 간격으로 이어 달린 주행을 반납해 기록으로 만든다.
    private func record(legs: [[CLLocationCoordinate2D]]) -> RideRecord {
        let start = Date().addingTimeInterval(-600)
        let session = RideSession(startStation: Fixtures.yeouinaru, pass: .oneHour, startedAt: start)
        var coordinates = legs.first ?? []
        for leg in legs.dropFirst() { coordinates += leg.dropFirst() }
        for (index, coordinate) in coordinates.enumerated() {
            session.record(Fixtures.location(coordinate, at: start.addingTimeInterval(Double(index)), speed: 5))
        }
        return RideRecord(session: session, endedAt: start.addingTimeInterval(Double(coordinates.count)), stations: Fixtures.stations)
    }

    @Test func 정류장_사이_기록은_도착_정류장_이름의_내_기록_코스가_된다() throws {
        let ride = record(legs: [Fixtures.line(yeouinaru, wonhyo, steps: 70)])
        let course = try #require(ride.makeCourse())

        #expect(course.isMyRide)
        #expect(course.id == "ride-\(ride.id.uuidString)")
        #expect(course.title == "여의도 한강공원 원효대교 남단")
        #expect(course.startStationID == "ST-YN-01")
        #expect(course.endStationID == "ST-YD-HG")
        #expect(abs(course.distanceMeters - 705) < 10)
        #expect(course.path.count == 71)
        // 1초 간격 71점 → 70초
        #expect(course.durationSeconds == 70)
        #expect(course.createdAt == ride.endedAt)
    }

    @Test func 정류장_밖_구간은_코스_경로에서_잘린다() throws {
        let ride = record(legs: [
            Fixtures.line(Fixtures.homeNorth, yeouinaru, steps: 100),
            Fixtures.line(yeouinaru, wonhyo, steps: 70),
        ])
        let course = try #require(ride.makeCourse())

        // 코스 첫 점은 출발 정류장 반경 안이고, 집 앞 점은 들어가지 않는다.
        let first = try #require(course.path.first)
        #expect(first.coordinate.location.distance(from: yeouinaru.location) <= StationMatcher.matchRadius)
        #expect(course.path.count < ride.pointCount)
        #expect(!course.path.contains { $0.coordinate.location.distance(from: Fixtures.homeNorth.location) < 50 })
    }

    @Test func 공유할_수_없는_기록은_코스로_만들지_않는다() {
        let ride = record(legs: [Fixtures.line(yeouinaru, Fixtures.homeNorth, steps: 100)])
        #expect(!ride.isShareable)
        #expect(ride.makeCourse() == nil)
    }

    @Test func 실제_주행_시간에서_끊긴_곳과_오래_빈_곳은_뺀다() {
        let start = Date()
        func point(_ second: Double) -> TrackPoint { Fixtures.trackPoint(yeouinaru, at: start.addingTimeInterval(second)) }
        // 0~3초 이동, 3→63초 일시정지(60초 빈 곳), 63~65초 이동, 65→200초 앱 종료(끊긴 곳), 200~202초 이동
        let points = [point(0), point(1), point(2), point(3), point(63), point(64), point(65), point(200), point(201), point(202)]

        let seconds = RideRecord.movingSeconds(points, segmentStarts: [7])

        #expect(seconds == 3 + 2 + 2)
    }

    @Test func 정류장별_조회는_그_정류장에서_출발한_공유_가능_기록만_최신순으로_고른다() {
        let older = record(legs: [Fixtures.line(yeouinaru, wonhyo, steps: 70)])
        older.endedAt = Date().addingTimeInterval(-3_600)
        let newer = record(legs: [Fixtures.line(yeouinaru, wonhyo, steps: 70)])
        let notShareable = record(legs: [Fixtures.line(yeouinaru, Fixtures.homeNorth, steps: 100)])
        let elsewhere = record(legs: [Fixtures.line(wonhyo, yeouinaru, steps: 70)])

        let picked = [older, notShareable, elsewhere, newer].shareable(departingFrom: "ST-YN-01")

        #expect(picked.map(\.id) == [newer.id, older.id])
    }

    @Test func 홈_카드는_도착이_매칭되면_출발과_도착을_한_줄씩_보여준다() {
        let matched = record(legs: [Fixtures.line(yeouinaru, wonhyo, steps: 70)])
        #expect(matched.cardTitle == "여의나루역 1번출구 앞\n→ 여의도 한강공원 원효대교 남단")

        let unmatched = record(legs: [Fixtures.line(yeouinaru, Fixtures.homeNorth, steps: 100)])
        #expect(unmatched.cardTitle == "여의나루역 1번출구 앞 출발")
    }
}
