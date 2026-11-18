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
    /// 대여하러 간 정류장("출발하기"를 누른 정류장). 실제로 경로가 시작된 정류장은 `matchedStartStationID`
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

    // MARK: 정류장 매칭 결과(StationMatcher, 노션 10-3). 서버 연동 후에는 서버가 다시 판정한다.
    /// 경로 앞쪽에서 처음 매칭된 정류장
    var matchedStartStationID: String?
    var matchedStartStationName: String?
    /// 경로 뒤쪽에서 마지막으로 매칭된 정류장. 공유 구간이 짧으면(정류장 밖에서 끝남 등) 비어 있다.
    var endStationID: String?
    var endStationName: String?
    /// 공유 구간(정류장 → 정류장)의 첫 점·마지막 점 인덱스. 그 앞뒤는 공유하지 않는다.
    var sharedStartIndex: Int?
    var sharedEndIndex: Int?
    var sharedLengthMeters: Double = 0
    /// 정류장별로 공유할 수 있는 기록인지. 실제 공유는 주행 요약 화면에서 사용자가 고른다(기본 비공개).
    var isShareable: Bool = false

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
    /// 홈 "나의 이용 기록" 카드 이름. 줄바꿈(\n)마다 한 줄씩, 줄마다 따로 줄인다(정류장 이름이 길어 카드 폭을 넘기 때문).
    /// - 출발·도착 정류장이 매칭됨: "여의나루역 1번출구 앞\n→ 여의도 한강공원 원효대교 남단"
    /// - 코스를 끝까지 안내받음: "원효대교 남단 강변길"
    /// - 그 외: "여의나루역 1번출구 앞 출발"
    var cardTitle: String {
        if let endStationName {
            return "\(matchedStartStationName ?? startStationName)\n→ \(endStationName)"
        }
        if let courseTitle, !courseCanceled {
            return courseTitle
        }
        return "\(matchedStartStationName ?? startStationName) 출발"
    }

    /// 카드 아래 줄: 날짜 · 달린 거리 · 주행 시간(실측)
    var cardSubtitle: String {
        let parts = Calendar.current.dateComponents([.month, .day], from: startedAt)
        let date = String(format: "%02d/%02d", parts.month ?? 0, parts.day ?? 0)
        return "\(date) · \(WeGoFormat.distance(Int(distanceMeters.rounded()))) · \(WeGoFormat.minutes(ridingSeconds))"
    }

    /// 끝난 주행 세션으로 기록을 만들고, 정류장 목록으로 출발·도착 정류장과 공유 구간을 판정해 넣는다.
    convenience init(session: RideSession, endedAt: Date, stations: [Station]) {
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
        applyMatch(
            StationMatcher.match(
                points: session.trackPoints.map(\.coordinate),
                segmentStarts: session.segmentStarts,
                stations: stations
            ),
            stations: stations
        )
    }
}

extension RideRecord {
    func applyMatch(_ match: StationMatcher.Result, stations: [Station]) {
        func name(_ id: String?) -> String? { stations.first { $0.id == id }?.name }
        matchedStartStationID = match.startStationID
        matchedStartStationName = name(match.startStationID)
        endStationID = match.endStationID
        endStationName = name(match.endStationID)
        sharedStartIndex = match.sharedRange?.lowerBound
        sharedEndIndex = match.sharedRange?.upperBound
        sharedLengthMeters = match.sharedLengthMeters
        isShareable = match.isShareable
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
/// AppState처럼 메인 스레드(화면 동작)에서만 부른다. 화면의 `@Query`와 같은 메인 컨텍스트에 써서 저장하면 바로 반영되게 한다.
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
        // AppState는 앱 시작 시 메인 스레드에서 만들어진다.
        let container = container
        context = MainActor.assumeIsolated { container.mainContext }
    }

    /// 반납 완료한 주행을 저장한다. 정류장 목록으로 출발·도착 정류장과 공유 구간을 함께 판정한다.
    /// TODO: 정류장 목록은 StationRepository(서버 정류장 목록 캐시)가 생기면 그 목록으로 바꾼다.
    func save(_ session: RideSession, endedAt: Date = .now, stations: [Station] = MockData.stations) {
        let record = RideRecord(session: session, endedAt: endedAt, stations: stations)
        context.insert(record)
        do {
            try context.save()
            logger.info("주행 기록 저장: \(record.pointCount, privacy: .public)점, \(Int(record.distanceMeters), privacy: .public)m, 압축 \(record.trackData.count, privacy: .public)B, 전체 \(self.count(), privacy: .public)건")
            logger.info("정류장 매칭: \(record.matchedStartStationName ?? "-", privacy: .public) → \(record.endStationName ?? "-", privacy: .public), 공유 구간 \(record.sharedStartIndex.map(String.init) ?? "-", privacy: .public)~\(record.sharedEndIndex.map(String.init) ?? "-", privacy: .public) \(Int(record.sharedLengthMeters), privacy: .public)m, 공유 가능 \(record.isShareable, privacy: .public)")
        } catch {
            logger.error("주행 기록 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 내 기록에서 만든 코스(`ride-<기록 ID>`)를 다시 찾는다. 진행 중 주행 복구 때 쓴다.
    func course(id: String) -> Course? {
        guard id.hasPrefix("ride-"), let uuid = UUID(uuidString: String(id.dropFirst("ride-".count))) else { return nil }
        var descriptor = FetchDescriptor<RideRecord>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.makeCourse()
    }

    func count() -> Int {
        (try? context.fetchCount(FetchDescriptor<RideRecord>())) ?? 0
    }
}
