import Foundation
import os
import UserNotifications

/// 주행 화면의 "10분 전 알림 받기": 대여 후 1시간 기준(시간권 길이) 10분 전에 로컬 알림을 보낸다.
/// 서버 푸시 없이 기기에서 예약하므로 앱이 꺼져 있어도 울린다.
final class RideReminder: NSObject, UNUserNotificationCenterDelegate {
    /// 알림을 보낼 시점: 시간권이 끝나기 이만큼 전
    static let leadTime: TimeInterval = 10 * 60

    private static let identifier = "wego.ride.passReminder"
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.matuna01.wego", category: "RideReminder")

    override init() {
        super.init()
        // 앱을 보고 있을 때도 배너로 보이게 한다.
        center.delegate = self
    }

    /// 알림 권한을 확인하고(처음이면 묻고) 예약한다. 권한이 없으면 false
    @discardableResult
    func schedule(for session: RideSession) async -> Bool {
        guard await requestAuthorizationIfNeeded() else {
            logger.info("알림 권한이 없어 예약하지 않음")
            return false
        }
        let fireDate = session.passEndsAt.addingTimeInterval(-Self.leadTime)
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 1 else {
            logger.info("알림 시점이 이미 지나 예약하지 않음")
            return true
        }

        let content = UNMutableNotificationContent()
        content.title = "1시간까지 10분 남았어요"
        content.body = Self.body(for: session.startStation.bikeOperator)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        do {
            try await center.add(request)
            logger.info("10분 전 알림 예약: \(fireDate.formatted(date: .omitted, time: .standard), privacy: .public)")
            return true
        } catch {
            logger.error("알림 예약 실패: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
        logger.info("10분 전 알림 취소")
    }

    /// 따릉이는 1시간마다 반납 후 다시 빌리면 추가요금이 없다(서울시 공식). 타슈는 재대여 규칙을 확인하기 전이라 반납 안내만 한다.
    private static func body(for bikeOperator: BikeOperator) -> String {
        switch bikeOperator {
        case .ttareungyi:
            "근처 정류장에서 반납하거나 다시 빌리면 추가요금이 없어요."
        case .tashu:
            "1시간이 지나면 추가요금이 붙어요. 가까운 정류장에 반납해 주세요."
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            return false
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
