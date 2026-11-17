import ActivityKit
import Foundation

/// 라이딩 중 잠금화면·다이나믹 아일랜드에 띄우는 Live Activity 데이터.
/// 앱(WeGo)과 위젯 확장(RideWidget) 두 타깃이 함께 컴파일한다.
///
/// 시간 표시는 위젯이 `Text(_:style: .timer)` 등으로 스스로 흐르게 하므로,
/// 매초 업데이트하지 않고 일시정지·재개와 거리 변화 때만 상태를 보낸다.
struct RideActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 누적 이동 거리(m)
        var distanceMeters: Double
        /// 주행 시간 타이머의 기준 시각 = 대여 시작 + 지금까지 일시정지한 시간
        var ridingClockStart: Date
        /// 일시정지 중이면 멈춘 시각, 달리는 중이면 nil
        var pausedAt: Date?
    }

    let stationName: String
    let operatorName: String
    let passTitle: String
    /// 대여 시작 시각(시간권은 일시정지와 무관하게 이때부터 흐른다)
    let startedAt: Date
    /// 시간권이 끝나는 시각. 이후는 초과 구간
    let passEndsAt: Date
}
