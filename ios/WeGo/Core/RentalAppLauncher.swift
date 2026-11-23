import Foundation
import SwiftUI

/// 대여, 반납은 따릉이/타슈 앱에서 한다(공개 API 없음, 내부 API 역분석 금지).
/// 운영사 앱을 URL 스킴으로 바로 열고, 앱이 없으면 그 앱의 App Store 페이지를 연다.
/// 스킴은 앱 실행만 된다(정류장 딥링크 없음). 스킴 확인은 앱 Info.plist의 CFBundleURLSchemes까지만 본다.
enum RentalAppLauncher {
    /// 운영사 앱을 여는 URL 스킴. 확인되지 않은 운영사는 nil(App Store 페이지만 연다).
    static func appURL(for bikeOperator: BikeOperator) -> URL? {
        switch bikeOperator {
        case .ttareungyi: URL(string: "bikeseoul://")
        case .tashu: nil // TODO(#47): 타슈 앱 URL 스킴 확인
        }
    }

    /// 운영사 앱의 App Store ID(Apple 공개 조회로 확인한 값)
    static func appStoreID(for bikeOperator: BikeOperator) -> String {
        switch bikeOperator {
        case .ttareungyi: "1037272004" // 서울자전거 따릉이(kr.go.seoul.seoulbike2015)
        case .tashu: "1634766279"      // 대전시 타슈(kr.or.newtashu.app)
        }
    }

    static func appStoreURL(for bikeOperator: BikeOperator) -> URL {
        URL(string: "itms-apps://apps.apple.com/app/id\(appStoreID(for: bikeOperator))")!
    }

    /// 여는 순서: 운영사 앱 -> App Store 페이지
    static func candidates(for bikeOperator: BikeOperator) -> [URL] {
        [appURL(for: bikeOperator), appStoreURL(for: bikeOperator)].compactMap { $0 }
    }
}

extension RentalAppLauncher {
    /// 운영사 앱을 열고, 앱이 없으면 App Store 페이지를 연다.
    /// 둘 다 못 여는 환경(시뮬레이터 등)이면 `onUnavailable`을 부른다.
    /// 설치 여부를 미리 묻지(canOpenURL) 않고 열기 결과로 판단하므로 Info.plist 등록이 필요 없다.
    @MainActor
    static func open(_ bikeOperator: BikeOperator, using openURL: OpenURLAction, onUnavailable: @escaping () -> Void) {
        open(candidates(for: bikeOperator)[...], using: openURL, onUnavailable: onUnavailable)
    }

    @MainActor
    private static func open(_ urls: ArraySlice<URL>, using openURL: OpenURLAction, onUnavailable: @escaping () -> Void) {
        guard let url = urls.first else {
            onUnavailable()
            return
        }
        openURL(url) { accepted in
            if !accepted { open(urls.dropFirst(), using: openURL, onUnavailable: onUnavailable) }
        }
    }
}

extension View {
    /// 운영사 앱에 다녀오는 흐름(대여·반납 공통): `isAwaiting`인 동안 앱이 다시 활성화되면 `perform`을 부른다.
    func onReturnFromOperatorApp(isAwaiting: Bool, perform: @escaping () -> Void) -> some View {
        modifier(OperatorAppReturnModifier(isAwaiting: isAwaiting, perform: perform))
    }
}

private struct OperatorAppReturnModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let isAwaiting: Bool
    let perform: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            if phase == .active, isAwaiting { perform() }
        }
    }
}
