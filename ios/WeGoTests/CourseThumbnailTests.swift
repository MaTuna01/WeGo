import CoreLocation
import Foundation
import Testing
import UIKit
@testable import WeGo

/// 코스 카드 썸네일과 표기(#55)
struct CourseThumbnailTests {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 50)

    @Test func 경로_그림은_칸_안에_비율을_지켜_가운데_맞추고_북쪽이_위다() {
        // 적도 근처라 경도 보정이 거의 없다. 가로 0.02, 세로 0.01 -> 100x50 칸을 꽉 채움
        let coordinates = [
            CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0.02),
        ]
        let points = CourseRouteGeometry.fit(coordinates, in: rect)
        #expect(points.count == 2)
        #expect(abs(points[0].x - 0) < 0.1 && abs(points[0].y - 50) < 0.1)   // 남서쪽 -> 왼쪽 아래
        #expect(abs(points[1].x - 100) < 0.1 && abs(points[1].y - 0) < 0.1)  // 북동쪽 -> 오른쪽 위
    }

    @Test func 세로로_긴_경로는_가로_가운데에_놓인다() {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
            CLLocationCoordinate2D(latitude: 0.01, longitude: 0.0),
        ]
        let points = CourseRouteGeometry.fit(coordinates, in: rect)
        #expect(points.allSatisfy { abs($0.x - 50) < 0.1 })
        #expect(abs(points[0].y - 50) < 0.1 && abs(points[1].y - 0) < 0.1)
    }

    @Test func 점이_하나뿐이거나_없으면_가운데_또는_빈_그림이다() {
        let one = CourseRouteGeometry.fit([CLLocationCoordinate2D(latitude: 37.5, longitude: 127)], in: rect)
        #expect(one == [CGPoint(x: 50, y: 25)])
        #expect(CourseRouteGeometry.fit([], in: rect).isEmpty)
    }

    @Test func 지도_영역은_경로를_여백과_함께_담고_짧은_코스도_최소_크기를_보장한다() {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 37.52, longitude: 126.92),
            CLLocationCoordinate2D(latitude: 37.53, longitude: 126.94),
        ]
        let region = CourseRouteGeometry.region(fitting: coordinates, padding: 1.5)!
        #expect(abs(region.center.latitude - 37.525) < 1e-9)
        #expect(abs(region.span.latitudeDelta - 0.015) < 1e-9)
        #expect(abs(region.span.longitudeDelta - 0.03) < 1e-9)

        let tiny = CourseRouteGeometry.region(fitting: [coordinates[0]])!
        #expect(tiny.span.latitudeDelta == 0.003)
        #expect(CourseRouteGeometry.region(fitting: []) == nil)
    }

    @Test func 사진을_넣으면_그_코스는_사진을_쓰고_지우면_다시_없다() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CoursePhotoStore(directory: directory)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }

        #expect(store.photo(for: "ride-1") == nil)
        #expect(store.save(image, for: "ride-1"))
        #expect(store.hasPhoto(for: "ride-1"))
        #expect(store.photo(for: "ride-1") != nil)
        #expect(store.photo(for: "ride-2") == nil)
        store.removePhoto(for: "ride-1")
        #expect(!store.hasPhoto(for: "ride-1"))
    }

    @Test func 사진_파일_이름에는_코스_ID의_특수문자를_쓰지_않는다() {
        let store = CoursePhotoStore(directory: URL(fileURLWithPath: "/tmp/photos"))
        #expect(store.fileURL(for: "ride-AB12_x").lastPathComponent == "ride-AB12_x.jpg")
        #expect(store.fileURL(for: "../../etc/passwd").lastPathComponent == "______etc_passwd.jpg")
    }

    @Test func 카드의_거리와_예상_시간_표기() {
        #expect(CourseRow.distanceParts(701) == ("701", "m"))
        #expect(CourseRow.distanceParts(1234) == ("1.2", "km"))
        #expect(CourseRow.approxMinutes(720) == 12)
        #expect(CourseRow.approxMinutes(10) == 1)
    }
}
