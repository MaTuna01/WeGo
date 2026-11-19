import Foundation
import Testing
@testable import WeGo

/// 서버 호출 기반: 주소 설정, 공통 헤더, ETag, 실패 분류
struct APIClientTests {
    private let configJSON = Data(#"{"minimumVersion": "1.0.0"}"#.utf8)

    // MARK: 주소 설정

    @Test func 주소가_비었거나_잘못되면_서버_없이_동작한다() {
        #expect(APIConfiguration(baseURLString: nil, appVersion: "1.0.0") == nil)
        #expect(APIConfiguration(baseURLString: "", appVersion: "1.0.0") == nil)
        #expect(APIConfiguration(baseURLString: "  \n", appVersion: "1.0.0") == nil)
        // xcconfig에서 // 를 /$()/ 로 적지 않으면 주석으로 잘려 "https:"만 남는다.
        #expect(APIConfiguration(baseURLString: "https:", appVersion: "1.0.0") == nil)
        #expect(APIConfiguration(baseURLString: "ftp://api.example.com", appVersion: "1.0.0") == nil)
        #expect(APIConfiguration(baseURLString: "api.example.com", appVersion: "1.0.0") == nil)
    }

    @Test func https_주소와_개발용_localhost_주소를_받는다() throws {
        let remote = try #require(APIConfiguration(baseURLString: " https://api.example.com ", appVersion: "1.0.0"))
        #expect(remote.baseURL.absoluteString == "https://api.example.com")
        #expect(APIConfiguration(baseURLString: "http://localhost:8080", appVersion: "1.0.0") != nil)
    }

    // MARK: 요청

    @Test func 모든_요청에_앱_버전과_Accept_헤더를_보낸다() async throws {
        let (client, host) = StubURLProtocol.client(appVersion: "1.2.3") { _ in (200, [:], configJSON) }
        _ = try await client.get("app/config", as: AppConfigResponse.self)

        let request = try #require(StubURLProtocol.requests(to: host).first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path() == "/app/config")
        #expect(request.value(forHTTPHeaderField: "X-App-Version") == "1.2.3")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "If-None-Match") == nil)
    }

    @Test func 기본_주소에_경로가_있으면_그_뒤에_붙인다() async throws {
        let (client, host) = StubURLProtocol.client(basePath: "/api/") { _ in (200, [:], configJSON) }
        _ = try await client.get("app/config", as: AppConfigResponse.self)
        #expect(StubURLProtocol.requests(to: host).first?.url?.path() == "/api/app/config")
    }

    // MARK: 응답

    @Test func 성공하면_디코딩하고_ETag를_돌려준다() async throws {
        let (client, _) = StubURLProtocol.client { _ in (200, ["ETag": #""v1""#], configJSON) }
        let result = try await client.get("app/config", as: AppConfigResponse.self)

        guard case let .fresh(config, etag) = result else {
            Issue.record("새 응답이어야 한다")
            return
        }
        #expect(config.minimumVersion == "1.0.0")
        #expect(etag == #""v1""#)
    }

    @Test func ETag를_보내고_304를_받으면_바뀐_게_없다고_알린다() async throws {
        let (client, host) = StubURLProtocol.client { request in
            request.value(forHTTPHeaderField: "If-None-Match") == #""v1""# ? (304, [:], Data()) : (200, [:], Data("{}".utf8))
        }
        let result = try await client.getData("stations", etag: #""v1""#)

        guard case .notModified = result else {
            Issue.record("304는 notModified여야 한다")
            return
        }
        #expect(StubURLProtocol.requests(to: host).first?.value(forHTTPHeaderField: "If-None-Match") == #""v1""#)
    }

    @Test func 실패는_종류별로_나눈다() async {
        let problem = Data(#"{"title": "Internal Server Error", "status": 500}"#.utf8)
        let (serverError, _) = StubURLProtocol.client { _ in (500, ["Content-Type": "application/problem+json"], problem) }
        await #expect(throws: APIError.status(500)) {
            try await serverError.getData("stations")
        }

        let (badBody, _) = StubURLProtocol.client { _ in (200, [:], Data("<html>".utf8)) }
        await #expect(throws: APIError.decoding) {
            try await badBody.get("app/config", as: AppConfigResponse.self)
        }

        let (offline, _) = StubURLProtocol.client { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: APIError.transport) {
            try await offline.getData("stations")
        }
    }

    @Test func 타임아웃과_캐시_설정() {
        let configuration = APIClient.makeSession().configuration
        #expect(configuration.timeoutIntervalForRequest == APIClient.requestTimeout)
        #expect(configuration.timeoutIntervalForResource == APIClient.resourceTimeout)
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }
}
