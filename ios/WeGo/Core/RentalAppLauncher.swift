import Foundation

/// 대여·반납은 따릉이/타슈 앱에서 한다(공개 API 없음, 내부 API 역분석 금지).
/// 앱을 여는 URL 스킴이 확인되면 `appURLScheme`을 채우고 Info.plist의 LSApplicationQueriesSchemes에 추가한다.
/// 그 전까지는 App Store 검색 화면을 연다.
enum RentalAppLauncher {
    static func appURLScheme(for bikeOperator: BikeOperator) -> URL? {
        switch bikeOperator {
        case .ttareungyi: nil // TODO: 따릉이 앱 URL 스킴 확인
        case .tashu: nil      // TODO: 타슈 앱 URL 스킴 확인
        }
    }

    static func url(for bikeOperator: BikeOperator) -> URL {
        if let scheme = appURLScheme(for: bikeOperator) { return scheme }
        var components = URLComponents(string: "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search")!
        components.queryItems = [
            URLQueryItem(name: "media", value: "software"),
            URLQueryItem(name: "term", value: bikeOperator.displayName),
        ]
        return components.url!
    }
}
