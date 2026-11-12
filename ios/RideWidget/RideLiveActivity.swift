import ActivityKit
import SwiftUI
import WidgetKit

/// 라이딩 중 잠금화면 배너와 다이나믹 아일랜드.
/// - 큰 숫자: 시간권 남은 시간. 끝나면 같은 타이머가 0부터 다시 올라가며 초과 시간을 보여준다.
/// - 작은 줄: 주행 시간(일시정지 시 멈춤) · 이동 거리
///
/// 위젯 확장에는 앱의 Pretendard 폰트와 WeGoColor가 없어서 시스템 폰트와 아래 색을 쓴다.
struct RideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(RideColor.background)
                .activitySystemActionForegroundColor(RideColor.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PassRemainingView(context: context, size: 28)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("이동 거리")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(RideText.kilometers(context.state.distanceMeters))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        RidingClockText(context: context)
                        Spacer(minLength: 0)
                        Text("\(context.attributes.stationName) 출발")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                Image(systemName: "bicycle")
                    .foregroundStyle(RideColor.primary)
            } compactTrailing: {
                PassTimerText(context: context)
                    .frame(width: 52, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            } minimal: {
                Image(systemName: "bicycle")
                    .foregroundStyle(context.isStale ? RideColor.overtime : RideColor.primary)
            }
            .keylineTint(RideColor.primary)
        }
    }
}

// MARK: - 잠금화면

private struct LockScreenView: View {
    let context: ActivityViewContext<RideActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bicycle")
                    .foregroundStyle(RideColor.primary)
                Text("\(context.attributes.operatorName) · \(context.attributes.passTitle)")
                    .font(.footnote.weight(.semibold))
                Spacer(minLength: 8)
                if context.state.pausedAt != nil {
                    Text("일시정지")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RideColor.chip, in: Capsule())
                }
            }

            HStack(alignment: .lastTextBaseline) {
                PassRemainingView(context: context, size: 38)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("이동 거리")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(RideText.kilometers(context.state.distanceMeters))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }

            RidingClockText(context: context)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !context.isStale {
                ProgressView(
                    timerInterval: context.attributes.startedAt...context.attributes.passEndsAt,
                    countsDown: true
                ) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(RideColor.primary)
            }
        }
        .foregroundStyle(RideColor.text)
        .padding(16)
    }
}

// MARK: - 공통 조각

/// "남은 시간 32:10" / 시간권이 끝나면 "시간권 초과 03:12"
private struct PassRemainingView: View {
    let context: ActivityViewContext<RideActivityAttributes>
    let size: CGFloat

    var body: some View {
        let isOver = context.isStale
        VStack(alignment: .leading, spacing: 0) {
            Text(isOver ? "시간권 초과" : "남은 시간")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isOver ? RideColor.overtime : .secondary)
            PassTimerText(context: context)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .frame(width: size * 3.9, alignment: .leading)
        }
    }
}

/// 시간권 타이머. 남은 시간을 거꾸로 세다가, 시간권이 끝나면(isStale) 초과 시간을 0부터 센다.
///
/// `Text(_:style: .timer)`는 잠긴 화면에서 "59분"처럼 분 단위로만 보이므로 `timerInterval`을 쓴다.
/// 타이머 Text는 가로폭을 최대한 차지하므로 쓰는 쪽에서 `frame(width:)`로 폭을 고정한다.
private struct PassTimerText: View {
    let context: ActivityViewContext<RideActivityAttributes>

    var body: some View {
        let start = context.attributes.startedAt
        let end = context.attributes.passEndsAt
        Group {
            if context.isStale {
                Text(timerInterval: end...end.addingTimeInterval(24 * 60 * 60), countsDown: false, showsHours: false)
                    .foregroundStyle(RideColor.overtime)
            } else {
                Text(timerInterval: start...end, countsDown: true, showsHours: false)
                    .foregroundStyle(RideColor.primary)
            }
        }
        .monospacedDigit()
    }
}

/// 주행 시간. 일시정지 중이면 멈춘 값에서 정지한다.
/// 타이머 Text는 가로폭을 최대한 차지하려 해서 옆 요소(큰 타이머)를 줄여 버리므로 폭을 고정한다.
private struct RidingClockText: View {
    let context: ActivityViewContext<RideActivityAttributes>

    var body: some View {
        let start = context.state.ridingClockStart
        HStack(spacing: 4) {
            Text("주행")
            Text(
                timerInterval: start...start.addingTimeInterval(24 * 60 * 60),
                pauseTime: context.state.pausedAt,
                countsDown: false,
                showsHours: true
            )
            .monospacedDigit()
            .frame(width: 60, alignment: .leading)
        }
        .fixedSize()
    }
}

private enum RideText {
    static func kilometers(_ meters: Double) -> String {
        String(format: "%.1fkm", max(0, meters) / 1000)
    }
}

/// WeGoColor 일부(primary FF7300, red FC5B31)를 옮겨 왔다.
private enum RideColor {
    static let primary = Color(red: 1.0, green: 0x73 / 255, blue: 0)
    static let overtime = Color(red: 0xFC / 255, green: 0x5B / 255, blue: 0x31 / 255)
    static let text = Color.primary
    static let background = Color(uiColor: .systemBackground).opacity(0.85)
    static let chip = Color.secondary.opacity(0.2)
}

// MARK: - 미리보기

#Preview("잠금화면", as: .content, using: RideActivityAttributes.preview) {
    RideLiveActivity()
} contentStates: {
    RideActivityAttributes.ContentState(distanceMeters: 1240, ridingClockStart: .now.addingTimeInterval(-1500), pausedAt: nil)
    RideActivityAttributes.ContentState(distanceMeters: 2310, ridingClockStart: .now.addingTimeInterval(-2000), pausedAt: .now)
}

#Preview("다이나믹 아일랜드", as: .dynamicIsland(.expanded), using: RideActivityAttributes.preview) {
    RideLiveActivity()
} contentStates: {
    RideActivityAttributes.ContentState(distanceMeters: 1240, ridingClockStart: .now.addingTimeInterval(-1500), pausedAt: nil)
}

private extension RideActivityAttributes {
    static var preview: RideActivityAttributes {
        RideActivityAttributes(
            stationName: "여의나루역 1번출구 앞",
            operatorName: "따릉이",
            passTitle: "1시간권",
            startedAt: .now.addingTimeInterval(-1600),
            passEndsAt: .now.addingTimeInterval(2000)
        )
    }
}
