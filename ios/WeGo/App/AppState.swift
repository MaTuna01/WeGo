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
    /// 정류장 시트에서 "코스 선택하기"로 지정한 코스. 대여 후 출발하면 이 코스로 안내한다.
    var plannedCourse: Course?

    @ObservationIgnored let location = LocationService()
    @ObservationIgnored private let rideActivity = RideActivityController()
    @ObservationIgnored private let rideReminder = RideReminder()
    private static let loginKey = "wego.isLoggedIn"
    private static let guestKey = "wego.isGuest"
    private static let reminderKey = "wego.rideReminderEnabled"

    /// 주행 화면의 "10분 전 알림 받기"(기본 켬). 바꾸면 진행 중인 주행의 알림을 바로 예약하거나 취소한다.
    var isRideReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isRideReminderEnabled, forKey: Self.reminderKey)
            updateRideReminder()
        }
    }
    /// 알림 권한이 꺼져 있어 예약하지 못했을 때 true(주행 화면이 안내를 띄운다)
    var isReminderPermissionDenied = false

    private(set) var isLoggedIn: Bool
    /// "비로그인으로 시작하기"로 들어온 상태. 지도·코스 보기·주행은 되고, 기록 저장·공유처럼 계정이 필요한 기능은 로그인을 요구한다.
    private(set) var isGuest: Bool

    init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: Self.loginKey)
        isGuest = UserDefaults.standard.bool(forKey: Self.guestKey)
        isRideReminderEnabled = UserDefaults.standard.object(forKey: Self.reminderKey) as? Bool ?? true
        RideActivityController.endAll()
        location.onRideUpdated = { [weak self] in
            guard let self, let ride = self.ride else { return }
            self.rideActivity.distanceDidChange(for: ride)
        }
    }

    func finishSplash() {
        phase = (isLoggedIn || isGuest) ? .main : .login
    }

    /// TODO: Sign in with Apple / Google ID 토큰 → 서버 검증 → WeGo JWT 발급으로 교체
    func signIn(with provider: AuthProvider) {
        setGuest(false)
        isLoggedIn = true
        UserDefaults.standard.set(true, forKey: Self.loginKey)
        phase = .main
    }

    /// 로그인 없이 메인으로 들어간다. 앱을 다시 켜도 로그인 화면을 거치지 않는다.
    func continueAsGuest() {
        setGuest(true)
        phase = .main
    }

    /// 로그아웃, 또는 비로그인 사용자가 로그인 화면으로 돌아갈 때
    func signOut() {
        endRide()
        setGuest(false)
        isLoggedIn = false
        UserDefaults.standard.set(false, forKey: Self.loginKey)
        phase = .login
    }

    private func setGuest(_ value: Bool) {
        isGuest = value
        UserDefaults.standard.set(value, forKey: Self.guestKey)
    }

    /// - course: 지정한 코스. 출발 정류장이 다르면 무시하고 자유 주행으로 시작한다.
    func startRide(from station: Station, pass: TimePass, course: Course? = nil) {
        let course = course.flatMap { $0.startStationID == station.id ? $0 : nil }
        let session = RideSession(startStation: station, pass: pass, course: course)
        plannedCourse = nil
        ride = session
        location.activeRide = session
        location.requestPermission()
        rideActivity.start(for: session)
        updateRideReminder()
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
        rideReminder.cancel()
        ride = nil
        location.activeRide = nil
        selectedTab = .home
    }

    private func updateRideReminder() {
        guard let ride, isRideReminderEnabled else {
            rideReminder.cancel()
            return
        }
        Task { @MainActor in
            let scheduled = await rideReminder.schedule(for: ride)
            isReminderPermissionDenied = !scheduled
            if !scheduled { isRideReminderEnabled = false }
        }
    }
}
