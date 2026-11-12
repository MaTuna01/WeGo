import ActivityKit
import Foundation

/// 라이딩 Live Activity(잠금화면 시간권 타이머)를 시작·갱신·종료한다.
/// 사용자가 설정에서 Live Activity를 꺼 두었으면 아무 일도 하지 않는다.
final class RideActivityController {
    private var activity: Activity<RideActivityAttributes>?
    /// 거리는 0.1km 단위로 보여주므로, 그 값이 바뀔 때만 갱신한다.
    private var lastDistanceStep: Int?

    func start(for session: RideSession) {
        Self.endAll()
        lastDistanceStep = nil
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = RideActivityAttributes(
            stationName: session.startStation.name,
            operatorName: session.startStation.bikeOperator.displayName,
            passTitle: session.pass.title,
            startedAt: session.startedAt,
            passEndsAt: session.passEndsAt
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: content(for: session),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    /// 일시정지·재개 직후
    func refresh(for session: RideSession) {
        push(content(for: session))
    }

    /// GPS로 거리가 늘었을 때. 0.1km 단위가 바뀔 때만 보낸다.
    func distanceDidChange(for session: RideSession) {
        let step = Int(session.distanceMeters / 100)
        guard step != lastDistanceStep else { return }
        lastDistanceStep = step
        push(content(for: session))
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// 라이딩은 아직 기기에 저장하지 않으므로, 앱이 종료됐다 다시 켜지면 남은 Live Activity를 정리한다.
    static func endAll() {
        let leftovers = Activity<RideActivityAttributes>.activities
        guard !leftovers.isEmpty else { return }
        Task {
            for activity in leftovers {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func push(_ content: ActivityContent<RideActivityAttributes.ContentState>) {
        guard let activity else { return }
        Task { await activity.update(content) }
    }

    /// staleDate를 시간권 종료 시각으로 두면, 그 시각에 위젯이 `isStale`로 다시 그려져 "초과" 표시로 바뀐다.
    private func content(for session: RideSession) -> ActivityContent<RideActivityAttributes.ContentState> {
        ActivityContent(
            state: RideActivityAttributes.ContentState(
                distanceMeters: session.distanceMeters,
                ridingClockStart: session.ridingClockStart,
                pausedAt: session.pausedAt
            ),
            staleDate: session.passEndsAt
        )
    }
}
