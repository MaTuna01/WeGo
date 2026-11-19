import MapKit
import Testing
@testable import WeGo

/// 지도에 그릴 정류장 고르기: 보이는 영역 근처만, 개수 제한, 너무 넓으면 확대 안내
struct StationMapFilterTests {
    private let center = CLLocationCoordinate2D(latitude: 37.5270, longitude: 126.9300)

    private func region(span: CLLocationDegrees) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
    }

    /// 중심에서 위도, 경도만큼 떨어진 정류장
    private func station(_ id: String, dLat: Double, dLon: Double) -> Station {
        Fixtures.station(id, id, center.latitude + dLat, center.longitude + dLon)
    }

    @Test func 보이는_영역과_가장자리_여유분_안의_정류장만_고른다() {
        // 영역 0.02도: 중심에서 0.01도가 화면 끝, 여유분 포함 0.015도까지 그린다.
        let all = [
            station("CENTER", dLat: 0, dLon: 0),
            station("EDGE", dLat: 0.0099, dLon: 0),
            station("MARGIN", dLat: 0, dLon: -0.014),
            station("FAR-N", dLat: 0.02, dLon: 0),
            station("FAR-E", dLat: 0, dLon: 0.03),
        ]
        let result = StationMapFilter.stations(all, in: region(span: 0.02))

        #expect(result.stations.map(\.id) == ["CENTER", "EDGE", "MARGIN"])
        #expect(!result.isZoomedOutTooFar)
    }

    @Test func 너무_많으면_화면_중심에서_가까운_순으로_자른다() {
        let all = (0..<10).map { station("S\($0)", dLat: Double($0) * 0.001, dLon: 0) }.shuffled()
        let result = StationMapFilter.stations(all, in: region(span: 0.05), maxCount: 3)
        #expect(result.stations.map(\.id) == ["S0", "S1", "S2"])
    }

    @Test func 가까운_순은_위도에_따른_경도_거리를_반영한다() {
        // 서울(위도 37.5)에서 경도 0.001도는 위도 0.001도보다 짧다(약 88m 대 111m).
        let all = [station("NORTH", dLat: 0.001, dLon: 0), station("EAST", dLat: 0, dLon: 0.001)]
        let result = StationMapFilter.stations(all, in: region(span: 0.05), maxCount: 1)
        #expect(result.stations.map(\.id) == ["EAST"])
    }

    @Test func 너무_넓게_축소하면_그리지_않고_안내한다() {
        let all = [station("CENTER", dLat: 0, dLon: 0)]
        let result = StationMapFilter.stations(all, in: region(span: StationMapFilter.maxLatitudeSpan + 0.01))
        #expect(result.stations.isEmpty)
        #expect(result.isZoomedOutTooFar)
    }

    @Test func 고른_정류장은_영역_밖이거나_축소해도_남긴다() {
        let all = [station("CENTER", dLat: 0, dLon: 0), station("PICKED", dLat: 0.05, dLon: 0)]

        let panned = StationMapFilter.stations(all, in: region(span: 0.02), selectedID: "PICKED")
        #expect(panned.stations.map(\.id) == ["CENTER", "PICKED"])

        let zoomedOut = StationMapFilter.stations(all, in: region(span: 0.5), selectedID: "PICKED")
        #expect(zoomedOut.stations.map(\.id) == ["PICKED"])

        let capped = StationMapFilter.stations(all, in: region(span: 0.2 / 3), selectedID: "PICKED", maxCount: 1)
        #expect(capped.stations.map(\.id).sorted() == ["CENTER", "PICKED"])
    }

    @Test func 수천_곳이어도_개수_제한을_지킨다() {
        // 3,000곳을 0.003도(약 300m) 간격 격자로 뿌린다. 영역 안에만 1,000곳 넘게 들어온다.
        let all = (0..<3_000).map { i in
            station("S\(i)", dLat: Double(i % 60) * 0.003 - 0.09, dLon: Double(i / 60) * 0.003 - 0.075)
        }
        let result = StationMapFilter.stations(all, in: region(span: 0.07))
        #expect(result.stations.count == StationMapFilter.maxCount)
    }
}
