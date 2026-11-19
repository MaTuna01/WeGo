import Foundation
import Observation
import OSLog

/// 정류장 목록. 서버 -> 기기 저장본 -> 앱 내장 목록 순서로 쓴다(docs/api-contract.md, 노션 9-7).
/// - 시작할 때 기기 저장본(없으면 앱 내장 목록)을 바로 읽어 화면을 띄우고, 서버는 뒤에서 확인한다.
/// - 마지막으로 서버에 확인한 지 1시간이 지나지 않았으면 다시 묻지 않고, ETag로 바뀐 경우만 받는다.
/// - 서버가 실패하거나 빈 목록, 깨진 응답을 주면 지금 목록을 그대로 쓴다.
@Observable
final class StationRepository {
    enum Source: Equatable {
        /// 앱에 넣어 둔 목록(서버에서 받은 적 없음)
        case bundled
        /// 지난번에 서버에서 받아 기기에 저장한 목록(이번 실행에서는 아직 확인 전)
        case cache
        /// 이번 실행에서 서버로 최신임을 확인한 목록
        case server
    }

    static let refreshInterval: TimeInterval = 60 * 60

    private(set) var stations: [Station] = []
    private(set) var source: Source = .bundled

    /// station(id:)만 부르는 화면도 목록이 바뀌면 다시 그려지도록 관찰 대상에 둔다.
    private var index: [Station.ID: Station] = [:]
    @ObservationIgnored private let client: APIClient?
    @ObservationIgnored private let cacheDirectory: URL
    @ObservationIgnored private var metadata: CacheMetadata?
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private let logger = Logger(subsystem: "com.matuna01.wego", category: "Stations")

    /// 저장본과 함께 남기는 정보
    struct CacheMetadata: Codable, Equatable {
        var etag: String?
        var checkedAt: Date
    }

    init(
        client: APIClient? = APIClient.shared,
        cacheDirectory: URL = StationRepository.defaultCacheDirectory,
        bundledData: Data? = StationRepository.loadBundledData()
    ) {
        self.client = client
        self.cacheDirectory = cacheDirectory

        if let data = try? Data(contentsOf: cacheFile), let list = Self.decode(data), !list.isEmpty {
            apply(list, source: .cache)
            metadata = (try? Data(contentsOf: metadataFile)).flatMap { try? JSONDecoder().decode(CacheMetadata.self, from: $0) }
        } else if let bundledData, let list = Self.decode(bundledData) {
            apply(list, source: .bundled)
        }
    }

    func station(id: Station.ID?) -> Station? {
        id.flatMap { index[$0] }
    }

    /// 앱 시작, 앱으로 돌아올 때 부른다. 서버 주소가 없는 빌드에서는 아무것도 하지 않는다.
    @MainActor
    func refresh(now: Date = .now) async {
        guard let client, !isRefreshing else { return }
        // 앱 내장 목록을 쓰는 중이면 기다리지 않고 바로 받는다.
        if source != .bundled, let checkedAt = metadata?.checkedAt,
           now.timeIntervalSince(checkedAt) < Self.refreshInterval, now >= checkedAt {
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }

        let etag = source == .bundled ? nil : metadata?.etag
        do {
            switch try await client.getData("stations", etag: etag) {
            case .notModified:
                guard source != .bundled else { return }
                saveMetadata(CacheMetadata(etag: etag, checkedAt: now))
                source = .server
            case let .fresh(data, newETag):
                guard let list = Self.decode(data), !list.isEmpty else {
                    logger.error("정류장 응답이 비었거나 계약과 달라 무시")
                    return
                }
                writeCache(data)
                saveMetadata(CacheMetadata(etag: newETag, checkedAt: now))
                apply(list, source: .server)
                logger.info("정류장 \(list.count, privacy: .public)곳 받음")
            }
        } catch {
            logger.error("정류장 조회 실패, 지금 목록 유지: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: 내부

    private func apply(_ list: [Station], source: Source) {
        stations = list
        index = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.source = source
    }

    private static func decode(_ data: Data) -> [Station]? {
        (try? JSONDecoder().decode(StationsResponse.self, from: data))?.validStations
    }

    private var cacheFile: URL { cacheDirectory.appending(path: "stations.json") }
    private var metadataFile: URL { cacheDirectory.appending(path: "stations-meta.json") }

    private func writeCache(_ data: Data) {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try data.write(to: cacheFile, options: .atomic)
        } catch {
            logger.error("정류장 저장 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func saveMetadata(_ value: CacheMetadata) {
        metadata = value
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try JSONEncoder().encode(value).write(to: metadataFile, options: .atomic)
        } catch {
            logger.error("정류장 저장 정보 기록 실패: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Application Support/Stations. 서버에서 다시 받을 수 있으므로 iCloud 백업에서는 뺀다.
    static var defaultCacheDirectory: URL {
        var url = URL.applicationSupportDirectory.appending(path: "Stations", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return url
    }

    /// Resources/Stations/bundled-stations.json(계약과 같은 모양). 서버 GET /stations 응답을 그대로 담아 둔 것.
    /// 서버 장애나 첫 실행 오프라인 때 쓰므로 출시 전에 최신 응답으로 갈아 둔다.
    static func loadBundledData() -> Data? {
        Bundle.main.url(forResource: "bundled-stations", withExtension: "json").flatMap { try? Data(contentsOf: $0) }
    }
}
