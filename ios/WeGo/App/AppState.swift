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
    /// 저장 탭의 "코스 보기"로 홈 정류장 시트에서 열어 달라고 한 코스(홈이 받아서 비운다)
    var requestedCourse: Course?

    /// 홈 탭으로 가서 코스의 출발 정류장 시트를 열고 그 코스를 고른다.
    func showOnHome(_ course: Course) {
        requestedCourse = course
        selectedTab = .home
    }

    @ObservationIgnored let location = LocationService()
    @ObservationIgnored private let rideActivity = RideActivityController()
    @ObservationIgnored private let rideReminder = RideReminder()
    /// 정류장 목록(서버 -> 기기 저장본 -> 앱 내장 목록). 주행 복구가 쓰므로 restoreActiveRide보다 먼저 만든다.
    @ObservationIgnored let stationRepository = StationRepository()
    /// 끝난 주행 기록(기기 저장)
    @ObservationIgnored let rideRecords = RideRecordStore()
    /// 진행 중 주행(앱이 꺼져도 이어서 기록)
    @ObservationIgnored private let activeRideStore = ActiveRideStore()
    /// 이보다 오래된 진행 중 주행은 복구하지 않고 그대로 끝난 기록으로 남긴다(반납을 잊고 앱을 지운 경우 등).
    private static let restoreLimit: TimeInterval = 12 * 60 * 60
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

    private var versionGate = MinimumVersionGate()
    /// 최소 지원 버전보다 낮아 앱 사용을 막아야 하면 true(RootView가 업데이트 안내로 덮는다)
    var isUpdateRequired: Bool { versionGate.isUpdateRequired }

    private(set) var isLoggedIn: Bool
    /// "비로그인으로 시작하기"로 들어온 상태. 지도·코스 보기·주행은 되고, 기록 저장·공유처럼 계정이 필요한 기능은 로그인을 요구한다.
    private(set) var isGuest: Bool

    init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: Self.loginKey)
        isGuest = UserDefaults.standard.bool(forKey: Self.guestKey)
        isRideReminderEnabled = UserDefaults.standard.object(forKey: Self.reminderKey) as? Bool ?? true
        location.onRideUpdated = { [weak self] in
            guard let self, let ride = self.ride else { return }
            self.rideActivity.distanceDidChange(for: ride)
            self.activeRideStore.saveIfNeeded(ride)
        }
        restoreActiveRide()
    }

    /// 앱 시작 때와 앱으로 돌아올 때 부른다. 확인 주기와 막힘 유지는 MinimumVersionGate가 정한다.
    @MainActor
    func checkMinimumVersion(using client: APIClient? = APIClient.shared) async {
        guard versionGate.beginCheck(at: .now) else { return }
        versionGate.finishCheck(updateRequired: await MinimumVersionCheck.isUpdateRequired(using: client))
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
        activeRideStore.save(session)
        updateRideReminder()
        selectedTab = .ride
    }

    func togglePauseRide() {
        guard let ride else { return }
        ride.togglePause()
        rideActivity.refresh(for: ride)
        activeRideStore.save(ride)
    }

    /// 코스 안내를 그만두고 자유 주행으로 바꾼다. 대여 시간·주행 기록·10분 전 알림·Live Activity는 그대로 이어진다
    /// (Live Activity에는 코스 정보가 없어 다시 보낼 것이 없다).
    func cancelCourse() {
        guard let ride else { return }
        ride.cancelCourse()
        activeRideStore.save(ride)
    }

    /// 앱이 백그라운드로 갈 때. 그대로 종료될 수 있으므로 진행 중 주행을 바로 저장한다.
    func persistActiveRide() {
        guard let ride else { return }
        activeRideStore.save(ride)
    }

    /// 반납 완료: 주행 기록을 기기에 저장하고 주행을 끝낸다.
    /// TODO: 라이딩 요약 화면(디자인 대기), 서버에 기록 업로드
    func endRide() {
        if let ride {
            rideRecords.save(ride, stations: stationRepository.stations)
        }
        activeRideStore.clear()
        rideActivity.end()
        rideReminder.cancel()
        ride = nil
        location.activeRide = nil
        selectedTab = .home
    }

    /// 앱을 다시 켰을 때 진행 중이던 주행을 되살린다. 주행 탭으로 가서 이어서 기록하고 Live Activity도 이어 쓴다.
    private func restoreActiveRide() {
        guard let snapshot = activeRideStore.load(),
              let station = stationRepository.station(id: snapshot.startStationID)
        else {
            activeRideStore.clear()
            RideActivityController.endAll()
            return
        }
        // 1.0의 코스는 내 기록에서 만든 코스(ride-...)뿐이다.
        func findCourse(_ id: String?) -> Course? {
            guard let id else { return nil }
            return rideRecords.course(id: id)
        }
        let course = findCourse(snapshot.courseID)
        let initialCourse = findCourse(snapshot.initialCourseID)
        let session = RideSession(restoring: snapshot, station: station, course: course, initialCourse: initialCourse)

        if Date.now.timeIntervalSince(session.startedAt) > Self.restoreLimit {
            // 너무 오래된 주행은 마지막 위치 시각에 끝난 것으로 기록만 남긴다.
            rideRecords.save(session, endedAt: session.trackPoints.last?.timestamp ?? session.startedAt, stations: stationRepository.stations)
            activeRideStore.clear()
            RideActivityController.endAll()
            return
        }

        ride = session
        location.activeRide = session
        location.requestPermission()
        rideActivity.resume(for: session)
        selectedTab = .ride
        // 예약해 둔 10분 전 알림은 앱이 꺼져도 남아 있지만, 토글 상태에 맞춰 다시 맞춘다.
        updateRideReminder()
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
