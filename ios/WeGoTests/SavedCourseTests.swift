import Foundation
import SwiftData
import Testing
@testable import WeGo

/// 코스 저장, 즐겨찾기(#48). 메모리 저장소로 확인한다.
@MainActor
struct SavedCourseTests {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: RideRecord.self, SavedCourse.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func course(_ id: String = "ride-1", title: String = "여의도 한강공원") -> Course {
        var course = Course(id: id, title: title, distanceMeters: 705, durationSeconds: 240)
        course.startStationID = "ST-YN-01"
        course.endStationID = "ST-YD-HG"
        course.path = [
            CoursePoint(latitude: 37.5271, longitude: 126.9329, elevationMeters: 12),
            CoursePoint(latitude: 37.5300, longitude: 126.9400, elevationMeters: nil),
        ]
        course.isMyRide = true
        return course
    }

    private func toggle(_ mark: CourseMark, _ course: Course, at seconds: TimeInterval = 0) -> Bool {
        SavedCourse.toggle(
            mark, for: course,
            startStationName: "여의나루역", endStationName: "원효대교 남단",
            in: context, now: Date(timeIntervalSince1970: seconds)
        )
    }

    private func all() throws -> [SavedCourse] {
        try context.fetch(FetchDescriptor<SavedCourse>())
    }

    @Test func 저장하면_코스_내용이_그대로_남는다() throws {
        #expect(toggle(.saved, course()))
        let saved = try #require(try all().first)
        #expect(saved.isSaved && !saved.isFavorite)
        #expect(saved.startStationName == "여의나루역")
        let restored = saved.course
        #expect(restored.id == "ride-1")
        #expect(restored.title == "여의도 한강공원")
        #expect(restored.startStationID == "ST-YN-01")
        #expect(restored.path == course().path)
        #expect(restored.isMyRide)
        #expect(restored.isSaved)
    }

    @Test func 저장과_즐겨찾기는_따로_켜고_끄며_둘_다_꺼지면_지운다() throws {
        _ = toggle(.saved, course())
        _ = toggle(.favorite, course())
        #expect(try all().count == 1)
        #expect(try all().first?.isFavorite == true)

        #expect(!toggle(.saved, course()))
        #expect(try all().count == 1)
        #expect(try all().first?.isSaved == false)

        #expect(!toggle(.favorite, course()))
        #expect(try all().isEmpty)
    }

    @Test func 표시를_켤_때마다_최신순_시각이_바뀐다() throws {
        _ = toggle(.saved, course(), at: 100)
        _ = toggle(.favorite, course(), at: 200)
        #expect(try all().first?.markedAt == Date(timeIntervalSince1970: 200))
        _ = toggle(.favorite, course(), at: 300)   // 끌 때는 그대로
        #expect(try all().first?.markedAt == Date(timeIntervalSince1970: 200))
    }

    @Test func 칩으로_거르고_최신순이나_이름순으로_정렬한다() throws {
        _ = toggle(.saved, course("a", title: "한강"), at: 100)
        _ = toggle(.favorite, course("b", title: "가로수길"), at: 200)
        _ = toggle(.saved, course("c", title: "나루터"), at: 300)
        _ = toggle(.favorite, course("c", title: "나루터"), at: 400)
        let courses = try all()

        let recent = SavedCourseFilter.apply(.all, sort: .recent, to: courses).map(\.courseID)
        #expect(recent == ["c", "b", "a"])
        let byName = SavedCourseFilter.apply(.all, sort: .name, to: courses).map(\.courseID)
        #expect(byName == ["b", "c", "a"])
        #expect(Set(SavedCourseFilter.apply(.saved, sort: .recent, to: courses).map(\.courseID)) == ["a", "c"])
        #expect(Set(SavedCourseFilter.apply(.favorite, sort: .recent, to: courses).map(\.courseID)) == ["b", "c"])
    }

    @Test func 경로_압축은_고도가_없는_점도_되살린다() {
        let path = course().path
        #expect(CoursePathCodec.decode(CoursePathCodec.encode(path)) == path)
        #expect(CoursePathCodec.decode(Data()).isEmpty)
    }
}
