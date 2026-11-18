import Foundation
import os
import SwiftData

/// 끝난 주행 1건. 서버 연동 전이라 기기(SwiftData)에만 저장한다.
/// 정류장·코스는 나중에 이름이 바뀌거나 목록에서 빠져도 기록을 보여줄 수 있게 ID와 함께 이름도 남긴다.
@Model
final class RideRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var startStationID: String
    var startStationName: String
    /// 안내받은 코스. 자유 주행으로 출발했으면 nil
    var courseID: String?
    var courseTitle: String?
    /// 코스 안내 중에 "코스 취소"로 자유 주행으로 바꿨는지
    var courseCanceled: Bool
    var distanceMeters: Double
    /// 일시정지를 뺀 주행 시간(초)
    var ridingSeconds: Double
    /// 대여 시작부터 반납까지(초)
    var rentalSeconds: Double
    var pointCount: Int
    /// 경로 점(`TrackPoint`) 목록을 압축한 것. 1초 간격이라 1시간이면 3,600점이 넘어 한 덩어리로 둔다.
    @Attribute(.externalStorage) var trackData: Data
    /// 경로가 끊긴 곳(앱이 꺼져 있던 구간)의 시작 인덱스
    var segmentStarts: [Int] = []

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        startStationID: String,
        startStationName: String,
        courseID: String?,
        courseTitle: String?,
        courseCanceled: Bool,
        distanceMeters: Double,
        ridingSeconds: Double,
        rentalSeconds: Double,
        trackPoints: [TrackPoint],
        segmentStarts: [Int] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.startStationID = startStationID
        self.startStationName = startStationName
        self.courseID = courseID
        self.courseTitle = courseTitle
        self.courseCanceled = courseCanceled
        self.distanceMeters = distanceMeters
        self.ridingSeconds = ridingSeconds
        self.rentalSeconds = rentalSeconds
        self.pointCount = trackPoints.count
        self.trackData = TrackCodec.encode(trackPoints)
        self.segmentStarts = segmentStarts
    }

    /// 저장된 경로 점. 압축을 풀어야 해서 목록 화면처럼 자주 그리는 곳에서는 부르지 않는다.
    var trackPoints: [TrackPoint] {
        TrackCodec.decode(trackData)
    }
}

extension RideRecord {
    /// 끝난 주행 세션으로 기록을 만든다.
    convenience init(session: RideSession, endedAt: Date) {
        self.init(
            startedAt: session.startedAt,
            endedAt: endedAt,
            startStationID: session.startStation.id,
            startStationName: session.startStation.name,
            courseID: session.initialCourse?.id,
            courseTitle: session.initialCourse?.title,
            courseCanceled: session.initialCourse != nil && session.course == nil,
            distanceMeters: session.distanceMeters,
            ridingSeconds: session.ridingElapsed(at: endedAt),
            rentalSeconds: session.rentalElapsed(at: endedAt),
            trackPoints: session.trackPoints,
            segmentStarts: session.segmentStarts
        )
    }
}

/// 경로 점 목록 ↔ 압축 바이너리. 프로퍼티 리스트(바이너리)로 직렬화한 뒤 LZFSE로 압축한다.
enum TrackCodec {
    private static let logger = Logger(subsystem: "com.matuna01.wego", category: "RideRecord")

    static func encode(_ points: [TrackPoint]) -> Data {
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let raw = try encoder.encode(points)
            return try (raw as NSData).compressed(using: .lzfse) as Data
        } catch {
            logger.error("경로 압축 실패: \(error.localizedDescription, privacy: .public)")
            return Data()
        }
    }

    static func decode(_ data: Data) -> [TrackPoint] {
        guard !data.isEmpty else { return [] }
        do {
            let raw = try (data as NSData).decompressed(using: .lzfse) as Data
            return try PropertyListDecoder().decode([TrackPoint].self, from: raw)
        } catch {
            logger.error("경로 압축 해제 실패: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

/// 주행 기록 저장소. 앱 전체에서 하나의 ModelContainer를 쓴다.
/// AppState처럼 메인 스레드(화면 동작)에서만 부른다.
final class RideRecordStore {
    let container: ModelContainer
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.matuna01.wego", category: "RideRecord")

    init() {
        do {
            container = try ModelContainer(for: RideRecord.self)
        } catch {
            // 저장소를 못 열어도 앱은 돌아가게 메모리 저장소로 대신한다(이번 실행 동안만 남음).
            Logger(subsystem: "com.matuna01.wego", category: "RideRecord")
                .error("기록 저장소 열기 실패, 메모리로 대체: \(error.localizedDescription, privacy: .public)")
            container = try! ModelContainer(
                for: RideRecord.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        context = ModelContext(container)
    }

    /// 반납 완료한 주행을 저장한다.
    func save(_ session: RideSession, endedAt: Date = .now) {
        let record = RideRecord(session: session, endedAt: endedAt)
        context.insert(record)
        do {
            try context.save()
            logger.info("주행 기록 저장: \(record.pointCount, privacy: .public)점, \(Int(record.distanceMeters), privacy: .public)m, 압축 \(record.trackData.count, privacy: .public)B, 전체 \(self.count(), privacy: .public)건")
        } catch {
            logger.error("주행 기록 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    func count() -> Int {
        (try? context.fetchCount(FetchDescriptor<RideRecord>())) ?? 0
    }
}
