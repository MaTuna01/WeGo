import Foundation

/// 점으로 나눈 숫자 버전(major.minor.patch). 빠진 자리는 0으로 본다(1.2 = 1.2.0).
struct AppVersion: Comparable, CustomStringConvertible {
    let components: [Int]

    /// 숫자와 점이 아닌 글자가 있거나 비어 있으면 nil
    init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.map { part in part.allSatisfy(\.isASCII) ? Int(part) : nil }
        guard !parts.isEmpty, numbers.allSatisfy({ ($0 ?? -1) >= 0 }) else { return nil }
        components = numbers.compactMap { $0 }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    var description: String { components.map(String.init).joined(separator: ".") }
}

/// 최소 지원 버전 확인(docs/api-contract.md GET /app/config).
/// 서버 문제로 앱 전체가 멈추면 안 되므로, 확실히 낮다고 판단될 때만 막고 나머지는 모두 통과시킨다.
enum MinimumVersionCheck {
    /// 현재 버전이 최소 지원 버전보다 낮으면 true. 둘 중 하나라도 해석할 수 없으면 false(막지 않음).
    static func isUpdateRequired(current: String, minimum: String) -> Bool {
        guard let current = AppVersion(current), let minimum = AppVersion(minimum) else { return false }
        return current < minimum
    }

    /// 서버에 물어본다. 서버 주소가 없거나, 연결 실패, 오류 응답, 디코딩 실패면 false.
    static func isUpdateRequired(using client: APIClient?) async -> Bool {
        guard let client else { return false }
        guard case let .fresh(config, _) = try? await client.get("app/config", as: AppConfigResponse.self) else { return false }
        return isUpdateRequired(current: client.configuration.appVersion, minimum: config.minimumVersion)
    }
}

/// 언제 다시 물어볼지와 막힘 상태. 앱을 오래 백그라운드에 두었다가 돌아온 경우에도 다시 확인하되,
/// 마지막 확인 후 1시간 안에는 묻지 않는다. 한 번 막히면 앱을 업데이트하기 전까지 풀지 않는다.
struct MinimumVersionGate {
    static let checkInterval: TimeInterval = 60 * 60

    private(set) var isUpdateRequired = false
    private var lastCheck: Date?

    /// 지금 서버에 물어봐야 하면 true를 돌려주고 확인 시각을 남긴다.
    mutating func beginCheck(at now: Date) -> Bool {
        guard !isUpdateRequired else { return false }
        if let lastCheck, now.timeIntervalSince(lastCheck) < Self.checkInterval { return false }
        lastCheck = now
        return true
    }

    mutating func finishCheck(updateRequired: Bool) {
        if updateRequired { isUpdateRequired = true }
    }
}

/// 이 앱의 App Store 페이지. 앱 ID는 Config/WeGo.xcconfig의 WEGO_APP_STORE_ID(App Store Connect의 Apple ID 숫자)에서 읽고,
/// 비어 있으면 App Store에서 "위고"를 검색한다.
enum AppStoreLink {
    static var current: URL {
        url(appID: Bundle.main.infoDictionary?["WeGoAppStoreID"] as? String)
    }

    static func url(appID: String?) -> URL {
        let id = appID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !id.isEmpty, id.allSatisfy(\.isASCII), id.allSatisfy(\.isNumber) {
            return URL(string: "itms-apps://apps.apple.com/app/id\(id)")!
        }
        var components = URLComponents(string: "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "software"),
            URLQueryItem(name: "term", value: "위고"),
        ]
        return components.url!
    }
}
