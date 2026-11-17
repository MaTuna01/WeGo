import Foundation
import Observation

enum AppPhase {
    case splash
    case login
    case main
}

enum AuthProvider {
    case google
    case apple
}

@Observable
final class AppState {
    var phase: AppPhase = .splash
    var selectedTab: MainTab = .home
    private(set) var ride: RideSession?

    @ObservationIgnored let location = LocationService()
    @ObservationIgnored private let rideActivity = RideActivityController()
    private static let loginKey = "wego.isLoggedIn"

    private(set) var isLoggedIn: Bool

    init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: Self.loginKey)
        RideActivityController.endAll()
        location.onRideUpdated = { [weak self] in
            guard let self, let ride = self.ride else { return }
            self.rideActivity.distanceDidChange(for: ride)
        }
    }

    func finishSplash() {
        phase = isLoggedIn ? .main : .login
    }

    /// TODO: Sign in with Apple / Google ID 토큰 → 서버 검증 → WeGo JWT 발급으로 교체
    func signIn(with provider: AuthProvider) {
        isLoggedIn = true
        UserDefaults.standard.set(true, forKey: Self.loginKey)
        phase = .main
    }

    func signOut() {
        endRide()
        isLoggedIn = false
        UserDefaults.standard.set(false, forKey: Self.loginKey)
        phase = .login
    }

    func startRide(from station: Station, pass: TimePass) {
        let session = RideSession(startStation: station, pass: pass)
        ride = session
        location.activeRide = session
        location.requestPermission()
        rideActivity.start(for: session)
        selectedTab = .ride
    }

    func togglePauseRide() {
        guard let ride else { return }
        ride.togglePause()
        rideActivity.refresh(for: ride)
    }

    /// TODO: 라이딩 요약 화면(디자인 대기) → 서버에 기록 저장
    func endRide() {
        rideActivity.end()
        ride = nil
        location.activeRide = nil
        selectedTab = .home
    }
}
