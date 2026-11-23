import MapKit
import Testing
@testable import WeGo

/// 지도 확대/축소 버튼의 영역 계산(#54)
struct MapZoomTests {
    private let center = CLLocationCoordinate2D(latitude: 37.5271, longitude: 126.9329)

    private func region(_ latitudeDelta: Double, _ longitudeDelta: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
    }

    @Test func 확대하면_가운데는_그대로_두고_영역을_줄인다() {
        let zoomed = MapZoom.region(region(0.02, 0.03), scaledBy: 0.5)
        #expect(zoomed.center.latitude == center.latitude)
        #expect(zoomed.center.longitude == center.longitude)
        #expect(abs(zoomed.span.latitudeDelta - 0.01) < 1e-9)
        #expect(abs(zoomed.span.longitudeDelta - 0.015) < 1e-9)
    }

    @Test func 축소하면_영역을_넓힌다() {
        let zoomed = MapZoom.region(region(0.02, 0.03), scaledBy: 2)
        #expect(abs(zoomed.span.latitudeDelta - 0.04) < 1e-9)
        #expect(abs(zoomed.span.longitudeDelta - 0.06) < 1e-9)
    }

    @Test func 최대_확대와_최대_축소에서_멈추고_가로세로_비율은_유지한다() {
        let tooClose = MapZoom.region(region(0.003, 0.006), scaledBy: 0.5)
        #expect(tooClose.span.latitudeDelta == MapZoom.minLatitudeSpan)
        #expect(abs(tooClose.span.longitudeDelta - MapZoom.minLatitudeSpan * 2) < 1e-9)

        let tooFar = MapZoom.region(region(0.4, 0.4), scaledBy: 2)
        #expect(tooFar.span.latitudeDelta == MapZoom.maxLatitudeSpan)
    }
}

/// 현재 위치 버튼: 시트에 가리지 않는 영역의 가운데로 옮기기
struct MapCenteringTests {
    private let me = CLLocationCoordinate2D(latitude: 37.5271, longitude: 126.9329)
    private let span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)

    @Test func 보이는_영역이_지도_전체면_내_위치가_지도_가운데다() {
        let region = MapZoom.region(centering: me, span: span, visibleTop: 0, visibleBottom: 1)
        #expect(abs(region.center.latitude - me.latitude) < 1e-12)
        #expect(region.center.longitude == me.longitude)
    }

    @Test func 시트가_아래를_가리면_지도_중심을_남쪽으로_내려_내_위치가_보이는_영역_가운데에_온다() {
        // 위 20%는 상단 바, 아래 40%는 시트 -> 보이는 영역 가운데는 위에서 40%
        let region = MapZoom.region(centering: me, span: span, visibleTop: 0.2, visibleBottom: 0.6)
        #expect(region.center.latitude < me.latitude)
        // 지도에서 위에서 40% 지점의 위도 = 중심 위도 + (0.5 - 0.4) * 위도 차
        let latitudeAtVisibleCenter = region.center.latitude + (0.5 - 0.4) * span.latitudeDelta
        #expect(abs(latitudeAtVisibleCenter - me.latitude) < 1e-12)
        #expect(region.span.latitudeDelta == span.latitudeDelta)
    }
}
