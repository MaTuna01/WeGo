import Foundation
@testable import WeGo

/// 네트워크 없이 서버 응답을 흉내 낸다. 테스트마다 다른 호스트를 쓰면 병렬로 돌아도 서로 섞이지 않는다.
final class StubURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (status: Int, headers: [String: String], body: Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]
    nonisolated(unsafe) private static var requests: [String: [URLRequest]] = [:]

    /// 새 호스트에 응답을 등록하고, 그 호스트를 쓰는 클라이언트를 돌려준다.
    static func client(basePath: String = "", appVersion: String = "1.0.0", handler: @escaping Handler) -> (client: APIClient, host: String) {
        let host = "\(UUID().uuidString.lowercased()).test"
        lock.withLock { handlers[host] = handler }
        let configuration = APIConfiguration(baseURLString: "https://\(host)\(basePath)", appVersion: appVersion)!
        let session = APIClient.makeSession(protocolClasses: [StubURLProtocol.self])
        return (APIClient(configuration: configuration, session: session), host)
    }

    /// 그 호스트로 들어온 요청들
    static func requests(to host: String) -> [URLRequest] {
        lock.withLock { requests[host] ?? [] }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host() ?? ""
        let handler = Self.lock.withLock {
            Self.requests[host, default: []].append(request)
            return Self.handlers[host]
        }
        do {
            guard let handler else { throw URLError(.cannotFindHost) }
            let (status, headers, body) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
