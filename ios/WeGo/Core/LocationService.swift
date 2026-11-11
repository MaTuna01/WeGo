import CoreLocation
import Observation

/// 위치 권한과 GPS 업데이트. 라이딩 중이면 세션에 위치를 기록한다.
/// TODO: 화면을 꺼도 기록하려면 Background Modes(Location updates) + Live Activity 작업이 필요하다.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?

    @ObservationIgnored var activeRide: RideSession?
    @ObservationIgnored private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    func requestPermission() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            startIfAuthorized()
        }
    }

    private func startIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        startIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            activeRide?.record(location)
        }
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 일시적 실패(kCLErrorLocationUnknown)는 무시하고 다음 업데이트를 기다린다.
    }
}
