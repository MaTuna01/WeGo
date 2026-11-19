import Foundation
import Testing
@testable import WeGo

/// 정류장 저장소: 서버 -> 기기 저장본 -> 앱 내장 목록, 1시간 간격, ETag 304
@MainActor
struct StationRepositoryTests {
    /// 테스트마다 비어 있는 저장 폴더
    private let directory = FileManager.default.temporaryDirectory.appending(path: "stations-\(UUID().uuidString)")

    private func body(_ ids: [String], operatorCode: String = "ttareungyi") -> Data {
        let items = ids.map {
            #"{"id": "\#($0)", "name": "정류장 \#($0)", "operator": "\#(operatorCode)", "latitude": 37.5, "longitude": 126.9, "dockCount": 10}"#
        }
        return Data(#"{"stations": [\#(items.joined(separator: ","))]}"#.utf8)
    }

    private var bundled: Data { body(["B-1", "B-2"]) }

    private func repository(_ client: APIClient?) -> StationRepository {
        StationRepository(client: client, cacheDirectory: directory, bundledData: bundled)
    }

    // MARK: 처음 실행

    @Test func 저장본이_없으면_앱_내장_목록을_쓴다() {
        let repo = repository(nil)
        #expect(repo.stations.map(\.id) == ["B-1", "B-2"])
        #expect(repo.source == .bundled)
        #expect(repo.station(id: "B-2")?.name == "정류장 B-2")
        #expect(repo.station(id: "NONE") == nil)
        #expect(repo.station(id: nil) == nil)
    }

    @Test func 실제_앱_내장_목록을_읽을_수_있다() throws {
        let data = try #require(StationRepository.loadBundledData())
        let repo = StationRepository(client: nil, cacheDirectory: directory, bundledData: data)
        #expect(!repo.stations.isEmpty)
        #expect(repo.stations.allSatisfy { $0.availableBikes == nil })
    }

    @Test func 서버_주소가_없으면_서버를_부르지_않는다() async {
        let repo = repository(nil)
        await repo.refresh()
        #expect(repo.source == .bundled)
    }

    // MARK: 서버

    @Test func 서버에서_받으면_목록을_바꾸고_다음_실행에서_저장본을_쓴다() async {
        let (client, _) = StubURLProtocol.client { _ in (200, ["ETag": #""v1""#], body(["S-1", "S-2", "S-3"])) }
        let repo = repository(client)
        await repo.refresh()

        #expect(repo.stations.map(\.id) == ["S-1", "S-2", "S-3"])
        #expect(repo.source == .server)
        #expect(repo.station(id: "S-3") != nil)
        #expect(repo.station(id: "B-1") == nil)

        // 앱을 다시 켜면(서버 연결 없이) 저장본을 읽는다.
        let relaunched = repository(nil)
        #expect(relaunched.stations.map(\.id) == ["S-1", "S-2", "S-3"])
        #expect(relaunched.source == .cache)
    }

    @Test func 한_시간_안에는_다시_묻지_않고_지나면_ETag를_보내_304면_그대로_쓴다() async {
        let (client, host) = StubURLProtocol.client { request in
            request.value(forHTTPHeaderField: "If-None-Match") == #""v1""#
                ? (304, [:], Data())
                : (200, ["ETag": #""v1""#], body(["S-1"]))
        }
        let now = Date()
        await repository(client).refresh(now: now)

        // 다시 켰을 때 1시간 안이면 묻지 않는다.
        let relaunched = repository(client)
        await relaunched.refresh(now: now.addingTimeInterval(30 * 60))
        #expect(StubURLProtocol.requests(to: host).count == 1)
        #expect(relaunched.source == .cache)

        // 1시간이 지나면 ETag를 보내고, 304면 저장본을 그대로 쓴다.
        await relaunched.refresh(now: now.addingTimeInterval(61 * 60))
        let requests = StubURLProtocol.requests(to: host)
        #expect(requests.count == 2)
        #expect(requests.last?.value(forHTTPHeaderField: "If-None-Match") == #""v1""#)
        #expect(relaunched.stations.map(\.id) == ["S-1"])
        #expect(relaunched.source == .server)

        // 304로 확인한 시각부터 다시 1시간을 센다.
        await relaunched.refresh(now: now.addingTimeInterval(90 * 60))
        #expect(StubURLProtocol.requests(to: host).count == 2)
    }

    @Test func 앱_내장_목록을_쓰는_중이면_ETag_없이_바로_받는다() async {
        let (client, host) = StubURLProtocol.client { _ in (200, [:], body(["S-1"])) }
        let repo = repository(client)
        await repo.refresh()
        #expect(StubURLProtocol.requests(to: host).first?.value(forHTTPHeaderField: "If-None-Match") == nil)
        #expect(repo.stations.map(\.id) == ["S-1"])
    }

    // MARK: 실패

    @Test func 서버가_실패하면_저장본을_그대로_쓴다() async {
        let (good, _) = StubURLProtocol.client { _ in (200, [:], body(["S-1"])) }
        let now = Date()
        await repository(good).refresh(now: now)

        let (failing, _) = StubURLProtocol.client { _ in throw URLError(.timedOut) }
        let relaunched = repository(failing)
        await relaunched.refresh(now: now.addingTimeInterval(2 * 60 * 60))
        #expect(relaunched.stations.map(\.id) == ["S-1"])
        #expect(relaunched.source == .cache)
    }

    @Test func 저장본도_없이_서버가_실패하면_앱_내장_목록을_쓴다() async {
        let (failing, _) = StubURLProtocol.client { _ in (500, [:], Data()) }
        let repo = repository(failing)
        await repo.refresh()
        #expect(repo.stations.map(\.id) == ["B-1", "B-2"])
        #expect(repo.source == .bundled)
    }

    @Test func 빈_목록이나_깨진_응답은_무시한다() async {
        for response in [body([]), Data("<html>".utf8), body(["X-1"], operatorCode: "eoulling")] {
            let (client, _) = StubURLProtocol.client { _ in (200, [:], response) }
            let repo = repository(client)
            await repo.refresh()
            #expect(repo.stations.map(\.id) == ["B-1", "B-2"])
            #expect(repo.source == .bundled)
        }
        // 저장본도 만들지 않는다.
        #expect(repository(nil).source == .bundled)
    }

    @Test func 저장본이_깨져_있으면_앱_내장_목록으로_시작한다() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: directory.appending(path: "stations.json"))
        let repo = repository(nil)
        #expect(repo.source == .bundled)
        #expect(repo.stations.map(\.id) == ["B-1", "B-2"])
    }
}
