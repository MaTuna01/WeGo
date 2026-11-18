import CoreLocation
import Foundation
@testable import WeGo

/// 테스트에서 함께 쓰는 정류장·경로 만들기. 좌표는 목업 정류장(여의도)을 기준으로 한다.
enum Fixtures {
    static let yeouinaru = station("ST-YN-01", "여의나루역 1번출구 앞", 37.52710, 126.93290)
    static let wonhyo = station("ST-YD-HG", "여의도 한강공원 원효대교 남단", 37.52320, 126.93920)
    static let assembly = station("ST-GH-01", "국회의사당역 1번출구", 37.52840, 126.91760)
    static let yeouido = station("ST-YD-05", "여의도역 5번출구", 37.52150, 126.92430)
    static let stations = [yeouinaru, wonhyo, assembly, yeouido]

    /// 정류장에서 먼 곳(집 앞 역할). 여의나루 → 집 직선이 다른 정류장을 지나지 않는다.
    static let homeNorth = coordinate(37.53300, 126.92300)
    /// 원효대교 남단에서 남동쪽. 원효대교 남단 → 집 직선이 다른 정류장을 지나지 않는다.
    static let homeSouthEast = coordinate(37.51800, 126.95000)

    static func station(_ id: String, _ name: String, _ latitude: Double, _ longitude: Double) -> Station {
        Station(
            id: id, name: name, bikeOperator: .ttareungyi,
            latitude: latitude, longitude: longitude,
            dockCount: 10, availableBikes: nil, updatedAt: nil
        )
    }

    static func coordinate(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// a에서 b까지 n등분한 직선 경로(양 끝 포함, n+1점)
    static func line(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, steps n: Int) -> [CLLocationCoordinate2D] {
        (0...n).map { i in
            let t = Double(i) / Double(n)
            return coordinate(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t)
        }
    }

    /// 경로 점 하나. 속도·고도를 정하지 않으면 모르는 값으로 둔다.
    static func trackPoint(
        _ coordinate: CLLocationCoordinate2D,
        at timestamp: Date,
        speed: Double = -1,
        horizontalAccuracy: Double = 5,
        altitude: Double? = nil
    ) -> TrackPoint {
        TrackPoint(location(coordinate, at: timestamp, speed: speed, horizontalAccuracy: horizontalAccuracy, altitude: altitude))
    }

    static func location(
        _ coordinate: CLLocationCoordinate2D,
        at timestamp: Date,
        speed: Double = -1,
        horizontalAccuracy: Double = 5,
        altitude: Double? = nil
    ) -> CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude ?? 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: altitude == nil ? -1 : 3,
            course: -1,
            speed: speed,
            timestamp: timestamp
        )
    }
}

extension CLLocationCoordinate2D {
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}
