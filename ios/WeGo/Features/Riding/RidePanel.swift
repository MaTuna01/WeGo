import SwiftUI

/// 주행 화면 하단 패널(402×202, Figma 299:343)에 보여줄 세 칸의 값
struct RideStats: Equatable {
    struct Item: Equatable {
        let title: String
        let value: String
    }

    let items: [Item]

    /// 코스 안내 주행: 총거리 / 남은 시간 / 예상 시간. 시간은 추정치라 "약 N분"으로만 보여준다.
    static func following(_ course: Course, remainingSeconds: Double?) -> RideStats {
        let remaining = remainingSeconds.map { Int($0.rounded()) } ?? course.durationSeconds
        return RideStats(items: [
            Item(title: "총거리", value: WeGoFormat.distance(course.distanceMeters)),
            Item(title: "남은 시간", value: remaining <= 30 ? "곧 도착" : WeGoFormat.approxMinutes(remaining)),
            Item(title: "예상 시간", value: WeGoFormat.approxMinutes(course.durationSeconds)),
        ])
    }

    /// 자유 주행: 달린 거리 / 주행 시간 / 1시간까지(시간권 기준 남은 시간)
    static func free(distanceMeters: Double, ridingSeconds: TimeInterval, remainingPassSeconds: TimeInterval) -> RideStats {
        let passValue = remainingPassSeconds >= 0
            ? WeGoFormat.minutesSeconds(remainingPassSeconds)
            : "초과 \(WeGoFormat.minutesSeconds(remainingPassSeconds))"
        return RideStats(items: [
            Item(title: "달린 거리", value: "\(WeGoFormat.kilometers(distanceMeters))km"),
            Item(title: "주행 시간", value: WeGoFormat.minutesSeconds(ridingSeconds)),
            Item(title: "1시간까지", value: passValue),
        ])
    }
}

/// 하단 패널: 세 칸 정보 + 코스 취소 / 반납하러가기
struct RideStatsPanel: View {
    let stats: RideStats
    let isPaused: Bool
    /// nil이면 코스 취소 버튼을 숨기고 반납하러가기를 전체 폭으로 보여준다(자유 주행).
    let onCancelCourse: (() -> Void)?
    let onReturn: () -> Void

    var body: some View {
        BottomSheetContainer(showsHandle: false) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(stats.items, id: \.title) { item in
                        VStack(spacing: 6) {
                            Text(item.title)
                                .wegoFont(.regular, 18, tracking: -0.5)
                                .foregroundStyle(WeGoColor.textBody)
                            Text(item.value)
                                .wegoFont(.bold, 26, tracking: -0.5)
                                .monospacedDigit()
                                .foregroundStyle(isPaused ? WeGoColor.gray500 : .black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 28)

                HStack(spacing: 22) {
                    if let onCancelCourse {
                        panelButton("코스 취소", background: WeGoColor.gray500, action: onCancelCourse)
                    }
                    panelButton("반납하러가기", background: WeGoColor.buttonDark, action: onReturn)
                }
                .padding(.horizontal, 17)
                .padding(.top, 27)

                Spacer(minLength: 0)
            }
        }
    }

    private func panelButton(_ title: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .wegoFont(.medium, 18, tracking: -0.5)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(background, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 상단 "10분 전 알림 받기" 바(368×47, Figma 299:347·349~351): 문구와 작은 토글을 가운데에 둔다.
struct RideReminderBar: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("10분 전 알림 받기")
                .wegoFont(.regular, 14, tracking: -0.7)
                .foregroundStyle(.black)
            // 디자인 토글은 39×22라 기본 토글(51×31)을 줄여 쓴다.
            Toggle("10분 전 알림 받기", isOn: $isOn)
                .labelsHidden()
                .tint(WeGoColor.primaryLight)
                .scaleEffect(0.76)
                .frame(width: 39, height: 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 47)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint("1시간 기준 10분 전에 알림을 보내요")
    }
}

/// 상단 응원 배너(360×60, Figma 299:393~395): 하늘 모자 오리 + 응원 문구
/// 진행률에 따라 문구를 바꿀지는 디자이너와 정하기로 해서, 지금은 디자인의 기본 문구만 쓴다.
struct RideCheerBanner: View {
    var message = "조금만 더 화이팅이에요~"

    var body: some View {
        HStack(spacing: 13) {
            Image("duckSkyHat")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 57)
            Text(message)
                .wegoFont(.medium, 17, tracking: -0.5)
                .foregroundStyle(.black)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.leading, 23)
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview("하단 패널") {
    VStack {
        RideCheerBanner()
            .padding(.horizontal, 21)
        Spacer()
        RideStatsPanel(
            stats: .following(MockData.previewCourse, remainingSeconds: 180),
            isPaused: false,
            onCancelCourse: {},
            onReturn: {}
        )
        .frame(height: 202)
    }
    .background(Color.gray.opacity(0.3))
}
