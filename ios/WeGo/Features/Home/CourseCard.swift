import SwiftUI

/// 코스 썸네일 카드. 와이어프레임은 회색 자리(#C7C7C7)뿐이라 코스 이름·거리만 얹었다.
/// TODO: 서버가 만드는 경로 이미지(썸네일)로 교체
struct CourseCard: View {
    let course: Course
    var showsMenu = false

    var body: some View {
        Rectangle()
            .fill(WeGoColor.placeholder)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.title)
                        .wegoFont(.semibold, 13, tracking: -0.4)
                        .lineLimit(1)
                    Text("\(WeGoFormat.distance(course.distanceMeters)) · \(WeGoFormat.approxMinutes(course.durationSeconds))")
                        .wegoFont(.regular, 11, tracking: -0.3)
                        .lineLimit(1)
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
