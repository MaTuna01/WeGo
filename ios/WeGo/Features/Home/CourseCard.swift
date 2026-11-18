import SwiftUI

/// 코스·주행 기록 썸네일 카드. 와이어프레임은 회색 자리(#C7C7C7)뿐이라 이름과 거리·시간만 얹었다.
/// TODO: 서버가 만드는 경로 이미지(썸네일)로 교체
struct CourseCard: View {
    let title: String
    let subtitle: String
    var showsMenu = false

    /// 코스: 거리 · 예상 시간("약 N분")
    init(course: Course, showsMenu: Bool = false) {
        self.init(
            title: course.title,
            subtitle: "\(WeGoFormat.distance(course.distanceMeters)) · \(WeGoFormat.approxMinutes(course.durationSeconds))",
            showsMenu: showsMenu
        )
    }

    /// - title: 줄바꿈(\n)으로 나누면 줄마다 한 줄씩 따로 줄여서 보여준다(예: 출발 정류장 / → 도착 정류장).
    init(title: String, subtitle: String, showsMenu: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.showsMenu = showsMenu
    }

    var body: some View {
        Rectangle()
            .fill(WeGoColor.placeholder)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(title.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .wegoFont(.semibold, 13, tracking: -0.4)
                            .lineLimit(1)
                    }
                    Text(subtitle)
                        .wegoFont(.regular, 11, tracking: -0.3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(WeGoColor.gray800)
                .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                if showsMenu {
                    Menu {
                        Button("코스 저장", systemImage: "bookmark") {}
                        Button("공유하기", systemImage: "square.and.arrow.up") {}
                    } label: {
                        // 세로 점 3개 (Figma 143:516~521: 3pt 점, 5pt 간격)
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle().fill(WeGoColor.gray900).frame(width: 3, height: 3)
                            }
                        }
                        .padding(.top, 9)
                        .padding(.trailing, 10)
                        .padding(.leading, 12)
                        .padding(.bottom, 10)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("코스 더보기")
                }
            }
            .accessibilityElement(children: .combine)
    }
}
