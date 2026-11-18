import CoreLocation
import Testing
@testable import WeGo

/// 코스 안내 주행의 진행 거리·남은 거리·남은 시간(코스 선에 현재 위치를 투영)
struct CourseProgressTests {
    // 여의나루 → 원효대교 남단(약 705m) → 여의도역 방향으로 꺾는 두 구간 코스
    private let a = Fixtures.yeouinaru.coordinate
    private let b = Fixtures.wonhyo.coordinate
    private let c = Fixtures.coordinate(37.52100, 126.93700)

    private var course: Course {
        var course = Course(id: "TEST", title: "테스트 코스", distanceMeters: 0, durationSeconds: 600)
        course.path = [
            CoursePoint(latitude: a.latitude, longitude: a.longitude, elevationMeters: 10),
            CoursePoint(latitude: b.latitude, longitude: b.longitude, elevationMeters: nil),
            CoursePoint(latitude: c.latitude, longitude: c.longitude, elevationMeters: 14),
        ]
        return course
    }

    private var firstLegMeters: Double { a.location.distance(from: b.location) }
    private var secondLegMeters: Double { b.location.distance(from: c.location) }

    @Test func 전체_길이는_구간_길이의_합이다() {
        let progress = CourseProgress(course: course)
        #expect(abs(progress.totalMeters - (firstLegMeters + secondLegMeters)) < 0.5)
    }

    @Test func 출발점에서는_전부_남았다() throws {
        let progress = CourseProgress(course: course)
        let snapshot = try #require(progress.snapshot(at: a))

        #expect(snapshot.traveledMeters < 1)
        #expect(abs(snapshot.remainingMeters - progress.totalMeters) < 1)
        #expect(abs(snapshot.remainingSeconds - 600) < 1)
        #expect(snapshot.fraction < 0.01)
    }

    @Test func 첫_구간_가운데에서는_그_절반만큼_왔다() throws {
        let middle = Fixtures.coordinate((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2)
        let progress = CourseProgress(course: course)
        let snapshot = try #require(progress.snapshot(at: middle))

        #expect(abs(snapshot.traveledMeters - firstLegMeters / 2) < 3)
        // 남은 시간은 코스 평균 속도(전체 길이 / 600초)로 환산한다.
        let expectedSeconds = snapshot.remainingMeters / (progress.totalMeters / 600)
        #expect(abs(snapshot.remainingSeconds - expectedSeconds) < 0.5)
    }

    @Test func 코스에서_조금_벗어나도_가장_가까운_지점으로_옮겨_계산한다() throws {
        let middle = Fixtures.coordinate((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2)
        let offRoute = Fixtures.coordinate(middle.latitude + 0.0002, middle.longitude + 0.0002) // 약 25m 옆
        let progress = CourseProgress(course: course)

        let onLine = try #require(progress.snapshot(at: middle))
        let beside = try #require(progress.snapshot(at: offRoute))

        #expect(abs(beside.traveledMeters - onLine.traveledMeters) < 40)
    }

    @Test func 도착점에서는_남은_거리와_시간이_0이다() throws {
        let snapshot = try #require(CourseProgress(course: course).snapshot(at: c))

        #expect(snapshot.remainingMeters < 1)
        #expect(snapshot.remainingSeconds < 1)
        #expect(snapshot.fraction > 0.99)
    }

    @Test func 경로_점이_2개_미만이면_계산하지_않는다() {
        var short = course
        short.path = Array(short.path.prefix(1))
        #expect(CourseProgress(course: short).snapshot(at: a) == nil)
    }

    @Test func 경사도_그래프는_고도가_있는_점만_쓴다() {
        let profile = CourseProgress(course: course).elevationProfile

        #expect(profile.map(\.elevationMeters) == [10, 14])
        #expect(profile.first?.distanceMeters == 0)
        #expect(abs((profile.last?.distanceMeters ?? 0) - (firstLegMeters + secondLegMeters)) < 0.5)
    }

    @Test func 경로_점_인덱스까지_거리는_범위를_넘으면_양_끝으로_맞춘다() {
        let progress = CourseProgress(course: course)

        #expect(progress.distance(toPathIndex: 0) == 0)
        #expect(abs(progress.distance(toPathIndex: 1) - firstLegMeters) < 0.5)
        #expect(progress.distance(toPathIndex: -3) == 0)
        #expect(progress.distance(toPathIndex: 99) == progress.totalMeters)
    }
}
