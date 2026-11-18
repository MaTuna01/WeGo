import Foundation

/// 내 주행 기록을 정류장 시트의 코스로 보여주기 위한 변환.
/// 서버 공유 경로가 생기기 전까지 정류장 시트 최신 탭에 목업 코스와 섞어 보여준다(#25).
extension RideRecord {
    /// 공유 구간(정류장 → 정류장)만 잘라 만든 코스. 공유할 수 없는 기록이면 nil.
    /// 정류장 밖 구간(예: 집 앞)은 경로에 넣지 않는다.
    /// 경로 점 압축을 풀어야 해서, 화면에서는 정류장이 바뀔 때만 만들고 그 사이에는 다시 만들지 않는다.
    func makeCourse() -> Course? {
        guard isShareable,
              let start = sharedStartIndex, let end = sharedEndIndex,
              let endStationID, let endStationName
        else { return nil }
        let points = trackPoints
        guard points.indices.contains(start), points.indices.contains(end), start < end else { return nil }
        let shared = Array(points[start...end])

        var course = Course(
            id: "ride-\(id.uuidString)",
            title: endStationName,
            distanceMeters: Int(sharedLengthMeters.rounded()),
            durationSeconds: Int(Self.movingSeconds(shared, segmentStarts: segmentStarts.map { $0 - start }).rounded())
        )
        course.startStationID = matchedStartStationID
        course.endStationID = endStationID
        course.path = shared.map { CoursePoint(latitude: $0.latitude, longitude: $0.longitude, elevationMeters: $0.altitude) }
        course.createdAt = endedAt
        course.isMyRide = true
        return course
    }

    /// 점 사이 시각 차이를 더한 실제 주행 시간. 앱이 꺼져 끊긴 곳과, 일시정지처럼 점 사이가 오래 빈 곳은 뺀다.
    static func movingSeconds(_ points: [TrackPoint], segmentStarts: [Int], maxGap: TimeInterval = 30) -> TimeInterval {
        guard points.count > 1 else { return 0 }
        let breaks = Set(segmentStarts)
        var total: TimeInterval = 0
        for index in 1..<points.count where !breaks.contains(index) {
            let gap = points[index].timestamp.timeIntervalSince(points[index - 1].timestamp)
            if gap > 0, gap <= maxGap { total += gap }
        }
        return total
    }
}

extension Array where Element == RideRecord {
    /// 이 정류장에서 출발한(출발 매칭된) 공유 가능 기록, 최신순
    func shareable(departingFrom stationID: Station.ID) -> [RideRecord] {
        filter { $0.isShareable && $0.matchedStartStationID == stationID }
            .sorted { $0.endedAt > $1.endedAt }
    }
}
