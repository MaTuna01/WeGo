import Foundation
import os
import SwiftData

/// 사용자가 저장(북마크)하거나 즐겨찾기(별)한 코스. 기기(SwiftData)에만 저장한다(서버 동기화는 1.3).
///
/// 내 기록에서 만든 코스는 원래 기록을 지워도 남도록 코스 내용을 통째로 담아 둔다(스냅샷).
/// 저장과 즐겨찾기는 코스마다 따로 켜고 끄며, 둘 다 꺼지면 이 행을 지운다.
@Model
final class SavedCourse {
    /// Course.id(내 기록이면 "ride-<기록 ID>")
    @Attribute(.unique) var courseID: String
    var title: String
    var startStationID: String?
    var startStationName: String
    var endStationID: String?
    var endStationName: String
    var distanceMeters: Int
    var durationSeconds: Int
    var isMyRide: Bool
    /// 경로 점(위도, 경도, 고도)을 압축한 것
    @Attribute(.externalStorage) var pathData: Data

    var isSaved: Bool
    var isFavorite: Bool
    /// 마지막으로 저장이나 즐겨찾기를 켠 시각(최신순 정렬)
    var markedAt: Date

    init(course: Course, startStationName: String, endStationName: String, markedAt: Date = .now) {
        courseID = course.id
        title = course.title
        startStationID = course.startStationID
        self.startStationName = startStationName
        endStationID = course.endStationID
        self.endStationName = endStationName
        distanceMeters = course.distanceMeters
        durationSeconds = course.durationSeconds
        isMyRide = course.isMyRide
        pathData = CoursePathCodec.encode(course.path)
        isSaved = false
        isFavorite = false
        self.markedAt = markedAt
    }

    /// 화면에서 쓰는 코스. 저장 여부도 채운다.
    var course: Course {
        var course = Course(id: courseID, title: title, distanceMeters: distanceMeters, durationSeconds: durationSeconds)
        course.startStationID = startStationID
        course.endStationID = endStationID
        course.path = CoursePathCodec.decode(pathData)
        course.isMyRide = isMyRide
        course.isSaved = isSaved
        course.createdAt = markedAt
        return course
    }
}

/// 코스에 붙이는 표시 두 가지
enum CourseMark: CaseIterable {
    /// 북마크(저장한 코스)
    case saved
    /// 별(즐겨찾기한 코스)
    case favorite

    var title: String {
        switch self {
        case .saved: "저장"
        case .favorite: "즐겨찾기"
        }
    }
}

extension SavedCourse {
    func has(_ mark: CourseMark) -> Bool {
        switch mark {
        case .saved: isSaved
        case .favorite: isFavorite
        }
    }

    /// 코스의 표시를 켜거나 끈다. 처음 켜면 코스 내용을 저장하고, 표시가 모두 꺼지면 지운다.
    /// - Returns: 바꾼 뒤 그 표시가 켜져 있는지
    @discardableResult
    static func toggle(
        _ mark: CourseMark,
        for course: Course,
        startStationName: String,
        endStationName: String,
        in context: ModelContext,
        now: Date = .now
    ) -> Bool {
        let saved = find(course.id, in: context)
            ?? {
                let new = SavedCourse(course: course, startStationName: startStationName, endStationName: endStationName, markedAt: now)
                context.insert(new)
                return new
            }()
        let isOn = !saved.has(mark)
        switch mark {
        case .saved: saved.isSaved = isOn
        case .favorite: saved.isFavorite = isOn
        }
        if isOn { saved.markedAt = now }
        if !saved.isSaved && !saved.isFavorite {
            context.delete(saved)
        }
        do {
            try context.save()
        } catch {
            Logger(subsystem: "com.matuna01.wego", category: "SavedCourse")
                .error("코스 \(mark.title) 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
        return isOn
    }

    static func find(_ courseID: String, in context: ModelContext) -> SavedCourse? {
        var descriptor = FetchDescriptor<SavedCourse>(predicate: #Predicate { $0.courseID == courseID })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }
}

/// 코스 경로 점 목록 <-> 압축 바이너리(주행 기록의 TrackCodec과 같은 방식)
enum CoursePathCodec {
    private struct Point: Codable {
        let lat: Double
        let lon: Double
        let ele: Double?
    }

    static func encode(_ path: [CoursePoint]) -> Data {
        let points = path.map { Point(lat: $0.latitude, lon: $0.longitude, ele: $0.elevationMeters) }
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let raw = try encoder.encode(points)
            return try (raw as NSData).compressed(using: .lzfse) as Data
        } catch {
            return Data()
        }
    }

    static func decode(_ data: Data) -> [CoursePoint] {
        guard !data.isEmpty,
              let raw = try? (data as NSData).decompressed(using: .lzfse) as Data,
              let points = try? PropertyListDecoder().decode([Point].self, from: raw)
        else { return [] }
        return points.map { CoursePoint(latitude: $0.lat, longitude: $0.lon, elevationMeters: $0.ele) }
    }
}
