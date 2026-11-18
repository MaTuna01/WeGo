import CoreLocation
import Testing
@testable import WeGo

/// 출발·도착 정류장 매칭과 공유 가능 구간 판정(노션 10-3, #23)
struct StationMatcherTests {
    private let stations = Fixtures.stations
    private let yeouinaru = Fixtures.yeouinaru.coordinate
    private let wonhyo = Fixtures.wonhyo.coordinate

    @Test func 정류장에서_정류장까지_달리면_공유할_수_있다() {
        let result = StationMatcher.match(points: Fixtures.line(yeouinaru, wonhyo, steps: 70), stations: stations)

        #expect(result.startStationID == "ST-YN-01")
        #expect(result.endStationID == "ST-YD-HG")
        #expect(result.sharedRange == 0...70)
        #expect(result.isShareable)
        // 여의나루 → 원효대교 남단 직선 약 705m
        #expect(abs(result.sharedLengthMeters - 705) < 5)
    }

    @Test func 정류장_밖에서_끝나면_공유할_수_없고_도착은_비운다() {
        let result = StationMatcher.match(points: Fixtures.line(yeouinaru, Fixtures.homeNorth, steps: 100), stations: stations)

        #expect(result.startStationID == "ST-YN-01")
        #expect(result.endStationID == nil)
        #expect(result.sharedRange == nil)
        #expect(!result.isShareable)
    }

    @Test func 정류장_밖에서_시작하면_앞부분을_잘라낸다() {
        let points = Fixtures.line(Fixtures.homeNorth, yeouinaru, steps: 100) + Fixtures.line(yeouinaru, wonhyo, steps: 70).dropFirst()
        let result = StationMatcher.match(points: points, stations: stations)

        #expect(result.startStationID == "ST-YN-01")
        #expect(result.endStationID == "ST-YD-HG")
        #expect(result.isShareable)
        // 집 앞 구간(0~90 근처)은 공유 구간에 들어가지 않는다.
        let range = try! #require(result.sharedRange)
        #expect(range.lowerBound > 80)
        #expect(range.upperBound == points.count - 1)
        #expect(result.sharedLengthMeters < 900)
    }

    @Test func 정류장을_지나_정류장_밖에서_끝나면_뒷부분을_잘라낸다() {
        let points = Fixtures.line(yeouinaru, wonhyo, steps: 70) + Fixtures.line(wonhyo, Fixtures.homeSouthEast, steps: 100).dropFirst()
        let result = StationMatcher.match(points: points, stations: stations)

        #expect(result.startStationID == "ST-YN-01")
        #expect(result.endStationID == "ST-YD-HG")
        #expect(result.isShareable)
        let range = try! #require(result.sharedRange)
        #expect(range.lowerBound == 0)
        #expect(range.upperBound < 90)
    }

    @Test func 같은_정류장으로_돌아온_왕복도_공유할_수_있다() {
        let points = Fixtures.line(yeouinaru, wonhyo, steps: 70) + Fixtures.line(wonhyo, yeouinaru, steps: 70).dropFirst()
        let result = StationMatcher.match(points: points, stations: stations)

        #expect(result.startStationID == "ST-YN-01")
        #expect(result.endStationID == "ST-YN-01")
        #expect(result.isShareable)
        #expect(abs(result.sharedLengthMeters - 1_410) < 10)
    }

    @Test func 대여_직후_바로_반납하면_최소_길이_미만이라_공유할_수_없다() {
        let nearby = Fixtures.coordinate(37.52740, 126.93320) // 여의나루에서 약 40m
        let result = StationMatcher.match(points: Fixtures.line(yeouinaru, nearby, steps: 10), stations: stations)

        #expect(result.startStationID == "ST-YN-01")
        #expect(result.endStationID == nil)
        #expect(!result.isShareable)
        #expect(result.sharedLengthMeters < StationMatcher.minimumSharedLength)
    }

    @Test func 근처에_정류장이_없으면_매칭되지_않는다() {
        let far = Fixtures.line(Fixtures.coordinate(37.55, 126.98), Fixtures.coordinate(37.56, 126.99), steps: 50)
        let result = StationMatcher.match(points: far, stations: stations)

        #expect(result == .unmatched)
    }

    @Test func 빈_경로는_매칭되지_않는다() {
        #expect(StationMatcher.match(points: [], stations: stations) == .unmatched)
    }

    @Test func 앱이_꺼져_끊긴_구간_사이_거리는_공유_길이에_더하지_않는다() {
        let full = Fixtures.line(yeouinaru, wonhyo, steps: 70)
        let gapped = Array(full[0...20]) + Array(full[50...70])

        let withBreak = StationMatcher.match(points: gapped, segmentStarts: [21], stations: stations)
        let withoutBreak = StationMatcher.match(points: gapped, stations: stations)

        #expect(withBreak.isShareable)
        #expect(abs(withoutBreak.sharedLengthMeters - 705) < 5)
        // 끊긴 사이(약 300m)를 뺀 길이
        #expect(withBreak.sharedLengthMeters < withoutBreak.sharedLengthMeters - 250)
    }

    @Test func 매칭은_반경_안에서_가장_가까운_정류장을_고른다() {
        let point = Fixtures.coordinate(37.52700, 126.93300) // 여의나루에서 약 15m
        #expect(StationMatcher.nearestStation(to: point, in: stations, within: 100)?.id == "ST-YN-01")
        #expect(StationMatcher.nearestStation(to: point, in: stations, within: 5) == nil)
    }
}
