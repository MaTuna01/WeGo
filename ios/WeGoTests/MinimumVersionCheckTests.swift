import Foundation
import Testing
@testable import WeGo

/// 최소 지원 버전 확인: 확실히 낮을 때만 막고, 서버 문제나 이상한 값이면 통과시킨다.
struct MinimumVersionCheckTests {
    private func config(_ minimum: String) -> Data {
        Data(#"{"minimumVersion": "\#(minimum)"}"#.utf8)
    }

    // MARK: 버전 비교

    @Test func 버전은_자리별_숫자로_비교한다() throws {
        let v = { (text: String) in try #require(AppVersion(text)) }
        #expect(try v("1.0.0") < v("1.0.1"))
        #expect(try v("1.9.0") < v("1.10.0")) // 문자열 비교면 반대가 된다
        #expect(try v("1.10.0") < v("2.0.0"))
        #expect(try !(v("1.0.1") < v("1.0.0")))
    }

    @Test func 빠진_자리는_0으로_본다() throws {
        #expect(try #require(AppVersion("1.2")) == #require(AppVersion("1.2.0")))
        #expect(try #require(AppVersion("2")) == #require(AppVersion("2.0.0")))
        #expect(try #require(AppVersion("1.2")) < #require(AppVersion("1.2.1")))
    }

    @Test func 해석할_수_없는_버전은_nil이다() {
        for text in ["", " ", "1..0", "1.0.", ".1", "1.0.0-beta", "v1.0", "1.a", "-1.0"] {
            #expect(AppVersion(text) == nil, "\(text)")
        }
        #expect(AppVersion(" 1.0.0 ")?.description == "1.0.0")
    }

    @Test func 현재_버전이_낮을_때만_업데이트가_필요하다() {
        #expect(MinimumVersionCheck.isUpdateRequired(current: "1.0.0", minimum: "1.0.1"))
        #expect(MinimumVersionCheck.isUpdateRequired(current: "1.9.9", minimum: "1.10"))
        #expect(!MinimumVersionCheck.isUpdateRequired(current: "1.0.0", minimum: "1.0.0"))
        #expect(!MinimumVersionCheck.isUpdateRequired(current: "1.2.0", minimum: "1.0.0"))
    }

    @Test func 둘_중_하나라도_이상한_값이면_막지_않는다() {
        #expect(!MinimumVersionCheck.isUpdateRequired(current: "1.0.0", minimum: ""))
        #expect(!MinimumVersionCheck.isUpdateRequired(current: "1.0.0", minimum: "latest"))
        #expect(!MinimumVersionCheck.isUpdateRequired(current: "", minimum: "9.0.0"))
    }

    // MARK: 서버 확인

    @Test func 서버의_최소_버전보다_낮으면_막는다() async {
        let (client, host) = StubURLProtocol.client(appVersion: "1.0.0") { _ in (200, [:], config("1.1.0")) }
        #expect(await MinimumVersionCheck.isUpdateRequired(using: client))
        #expect(StubURLProtocol.requests(to: host).first?.url?.path() == "/app/config")
    }

    @Test func 서버의_최소_버전_이상이면_통과한다() async {
        let (client, _) = StubURLProtocol.client(appVersion: "1.1.0") { _ in (200, [:], config("1.1.0")) }
        #expect(await !MinimumVersionCheck.isUpdateRequired(using: client))
    }

    @Test func 서버가_없거나_실패하면_막지_않는다() async {
        #expect(await !MinimumVersionCheck.isUpdateRequired(using: nil))

        let (offline, _) = StubURLProtocol.client { _ in throw URLError(.timedOut) }
        #expect(await !MinimumVersionCheck.isUpdateRequired(using: offline))

        let (serverError, _) = StubURLProtocol.client { _ in (503, [:], Data()) }
        #expect(await !MinimumVersionCheck.isUpdateRequired(using: serverError))

        let (badBody, _) = StubURLProtocol.client { _ in (200, [:], Data(#"{"min": "9.0.0"}"#.utf8)) }
        #expect(await !MinimumVersionCheck.isUpdateRequired(using: badBody))
    }

    // MARK: 확인 주기

    @Test func 마지막_확인_후_1시간_안에는_다시_묻지_않는다() {
        var gate = MinimumVersionGate()
        let now = Date()

        let first = gate.beginCheck(at: now)
        gate.finishCheck(updateRequired: false)
        let within = gate.beginCheck(at: now.addingTimeInterval(59 * 60))
        let after = gate.beginCheck(at: now.addingTimeInterval(61 * 60))

        #expect(first)
        #expect(!within)
        #expect(after)
        #expect(!gate.isUpdateRequired)
    }

    @Test func 한_번_막히면_다시_묻지_않고_풀지도_않는다() {
        var gate = MinimumVersionGate()
        let now = Date()

        _ = gate.beginCheck(at: now)
        gate.finishCheck(updateRequired: true)
        let nextDay = gate.beginCheck(at: now.addingTimeInterval(24 * 60 * 60))
        gate.finishCheck(updateRequired: false)

        #expect(!nextDay)
        #expect(gate.isUpdateRequired)
    }

    // MARK: App Store 링크

    @Test func 앱_ID가_있으면_앱_페이지를_없으면_검색을_연다() {
        #expect(AppStoreLink.url(appID: "1234567890").absoluteString == "itms-apps://apps.apple.com/app/id1234567890")
        for id in [nil, "", "  ", "abc"] as [String?] {
            let url = AppStoreLink.url(appID: id)
            #expect(url.host() == "search.itunes.apple.com")
            #expect(url.query()?.contains("media=software") == true)
        }
    }
}
