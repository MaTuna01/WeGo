import Foundation

/// 서버 연결 설정. 주소는 빌드 설정(Config/WeGo.xcconfig의 WEGO_API_BASE_URL -> Info.plist WeGoAPIBaseURL)에서 읽는다.
struct APIConfiguration: Equatable {
    let baseURL: URL
    /// 모든 요청의 X-App-Version 헤더 값
    let appVersion: String

    /// 이 앱 빌드의 설정. 주소가 비었거나 잘못됐으면 nil이고, 그때는 서버를 호출하지 않는다.
    static let current: APIConfiguration? = {
        let info = Bundle.main.infoDictionary ?? [:]
        return APIConfiguration(
            baseURLString: info["WeGoAPIBaseURL"] as? String,
            appVersion: info["CFBundleShortVersionString"] as? String ?? "0.0.0"
        )
    }()

    /// http(s) 주소만 받는다. 외부 주소의 HTTP는 ATS가 막고, localhost만 개발용으로 열려 있다.
    init?(baseURLString: String?, appVersion: String) {
        guard let text = baseURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host(), !host.isEmpty
        else { return nil }
        self.baseURL = url
        self.appVersion = appVersion
    }
}

enum APIError: Error, Equatable {
    /// 연결 실패, 타임아웃, 오프라인
    case transport
    /// HTTP 응답이 아님
    case invalidResponse
    /// 2xx, 304가 아닌 상태 코드(본문은 ProblemDetail이지만 해석하지 않는다)
    case status(Int)
    /// 응답 본문이 계약과 다름
    case decoding
}

enum APIResult<Value> {
    /// 새 응답과 그 ETag(있으면)
    case fresh(Value, etag: String?)
    /// If-None-Match로 보낸 ETag와 같아서 바뀐 게 없음(304)
    case notModified
}

/// Spring 서버 호출. 앱은 이 서버하고만 통신한다(docs/api-contract.md).
/// 캐시는 저장소가 ETag로 직접 관리하므로 URLSession 캐시는 끈다.
struct APIClient {
    static let requestTimeout: TimeInterval = 10
    static let resourceTimeout: TimeInterval = 30

    /// 서버 주소가 설정된 빌드에서만 있다.
    static let shared: APIClient? = APIConfiguration.current.map { APIClient(configuration: $0) }

    let configuration: APIConfiguration
    private let session: URLSession

    init(configuration: APIConfiguration, session: URLSession = APIClient.makeSession()) {
        self.configuration = configuration
        self.session = session
    }

    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.waitsForConnectivity = false
        if let protocolClasses { config.protocolClasses = protocolClasses }
        return URLSession(configuration: config)
    }

    /// GET 요청. path는 기본 주소 뒤에 붙는다(예: "stations", "app/config").
    func makeRequest(_ path: String, etag: String? = nil) -> URLRequest {
        var request = URLRequest(url: configuration.baseURL.appending(path: path))
        request.httpMethod = "GET"
        request.setValue(configuration.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        return request
    }

    /// 본문을 그대로 받는다. 저장소가 원본을 기기에 저장할 때 쓴다.
    func getData(_ path: String, etag: String? = nil) async throws -> APIResult<Data> {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: makeRequest(path, etag: etag))
        } catch {
            throw APIError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return .fresh(data, etag: http.value(forHTTPHeaderField: "ETag"))
        case 304:
            return .notModified
        default:
            throw APIError.status(http.statusCode)
        }
    }

    func get<Value: Decodable>(_ path: String, as type: Value.Type, etag: String? = nil) async throws -> APIResult<Value> {
        switch try await getData(path, etag: etag) {
        case .notModified:
            return .notModified
        case let .fresh(data, etag):
            do {
                return .fresh(try JSONDecoder().decode(type, from: data), etag: etag)
            } catch {
                throw APIError.decoding
            }
        }
    }
}
