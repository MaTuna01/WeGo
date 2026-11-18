import CoreLocation
import Observation

/// 위치 권한과 GPS 업데이트. 라이딩 중이면 세션에 위치를 기록한다.
/// 라이딩 중에는 화면을 꺼도 기록을 이어간다(Background Modes: location, 상단에 위치 사용 표시가 뜬다).
/// 위치는 거리 필터 없이 모두 받는다(움직이는 동안 약 1초 간격). 흔들림은 `RideSession`이 거른다.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?

    @ObservationIgnored var activeRide: RideSession? {
        didSet {
            let riding = activeRide != nil
            manager.allowsBackgroundLocationUpdates = riding
            manager.showsBackgroundLocationIndicator = riding
            // 신호 대기처럼 잠깐 멈춰도 iOS가 위치 업데이트를 스스로 멈추지 않게 한다(쉰 시간도 기록).
            manager.pausesLocationUpdatesAutomatically = !riding
        }
    }
    /// 라이딩 중 위치를 기록한 뒤 호출된다(Live Activity 거리 갱신용).
    @ObservationIgnored var onRideUpdated: (() -> Void)?
    @ObservationIgnored private let manager: CLLocationManager

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
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
        if activeRide != nil { onRideUpdated?() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 일시적 실패(kCLErrorLocationUnknown)는 무시하고 다음 업데이트를 기다린다.
    }
}
