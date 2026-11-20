import Foundation
import Testing
@testable import WeGo

/// 운영사 앱 열기 순서(#45): 운영사 앱 스킴 -> App Store 페이지
struct RentalAppLauncherTests {
    @Test func 따릉이는_앱_스킴을_먼저_열고_다음에_App_Store_페이지를_연다() {
        let urls = RentalAppLauncher.candidates(for: .ttareungyi).map(\.absoluteString)
        #expect(urls == [
            "bikeseoul://",
            "itms-apps://apps.apple.com/app/id1037272004",
        ])
    }

    @Test func 스킴이_없는_운영사는_App_Store_페이지만_연다() {
        let urls = RentalAppLauncher.candidates(for: .tashu).map(\.absoluteString)
        #expect(urls == ["itms-apps://apps.apple.com/app/id1634766279"])
    }

    @Test func 모든_운영사는_App_Store_페이지가_마지막_대안이다() {
        for bikeOperator in BikeOperator.allCases {
            let urls = RentalAppLauncher.candidates(for: bikeOperator)
            #expect(urls.last == RentalAppLauncher.appStoreURL(for: bikeOperator))
            #expect(urls.last?.scheme == "itms-apps")
        }
    }
}
