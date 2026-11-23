import SwiftUI

/// 코스 상세 (Figma 299:224). 정류장 시트에서 선택된 코스 카드를 한 번 더 누르면 들어온다.
/// 위에서부터: 출발 → 도착 카드(왼쪽 위 뒤로가기), 경사도, 코스 정보, 사용자 후기.
/// 하단 "코스 선택 / 대여하기" 버튼은 정류장 시트가 목록과 같이 붙여 준다.
struct CourseDetailView: View {
    let course: Course
    let startName: String
    let endName: String
    let onBack: () -> Void

    var body: some View {
        // 시트를 펼쳤을 때만 스크롤된다(DraggableBottomSheet).
        SheetScrollView {
            VStack(alignment: .leading, spacing: 0) {
                details
                    .padding(.horizontal, 20)
                // 후기 카드는 화면 오른쪽 끝까지 이어지도록 좌우 여백 밖에 둔다.
                reviews
                    .padding(.top, 9)
                    .padding(.bottom, 8)
            }
        }
    }

    /// 출발 → 도착 카드, 경사도 카드(그래프 + 코스 정보), 후기 제목
    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            CourseRouteCard(course: course, startName: startName, endName: endName)
                .overlay(alignment: .topLeading) { backButton }

            sectionTitle("경사도")
                .padding(.top, 26)

            // 경사도 카드(362×307): 위는 그래프, 구분선 아래는 코스 정보
            VStack(spacing: 0) {
                ElevationChart(course: course)
                    .padding(.top, 53)
                Rectangle()
                    .fill(WeGoColor.border)
                    .frame(height: 1)
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                stats
                    .padding(.top, 18)
            }
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 2)

            // 후기가 없으면 제목까지 숨긴다(1.0은 후기 기능이 없음).
            if !course.reviews.isEmpty {
                sectionTitle("사용자 후기")
                    .padding(.top, 11)
            }
        }
    }

    /// 총거리 / 최고 고도 / 예상 시간. 예상 시간은 ±20% 오차라 "약 N분"으로만 보여준다.
    private var stats: some View {
        HStack(spacing: 0) {
            stat("총거리", WeGoFormat.distance(course.distanceMeters))
            stat("최고 고도", course.maxElevationMeters.map { "\(Int($0.rounded()))m" } ?? "정보 없음")
            stat("예상 시간", WeGoFormat.approxMinutes(course.durationSeconds))
        }
        .padding(.horizontal, 8)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .wegoFont(.regular, 18, tracking: -0.5)
                .foregroundStyle(WeGoColor.textBody)
            Text(value)
                .wegoFont(.semibold, 20, tracking: -0.5)
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// 가로로 넘기는 후기 카드(253×104). 카드가 화면 오른쪽 밖까지 이어지게 좌우 여백은 안쪽에만 둔다.
    @ViewBuilder
    private var reviews: some View {
        if !course.reviews.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(course.reviews) { review in
                        ReviewCard(review: review)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .wegoFont(.regular, 14, tracking: -0.7)
            .foregroundStyle(.black)
            .frame(height: 21)
    }

    /// 카드 왼쪽 위 `<` (디자인: 카드 안 x8, y-9)
    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("코스 목록으로")
    }
}

/// 후기 카드: 왼쪽 사진(107×86), 오른쪽 별점 5개와 후기 글(2줄)
private struct ReviewCard: View {
    let review: CourseReview

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            photo
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(index <= review.rating ? WeGoColor.yellow : WeGoColor.gray300)
                    }
                }
                Text(review.text)
                    .wegoFont(.regular, 13, tracking: -0.4, lineHeight: 18)
                    .foregroundStyle(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 21)
            }
            .padding(.top, 3)
            Spacer(minLength: 0)
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .frame(width: 253, height: 104, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("별점 \(review.rating)점. \(review.text)")
    }

    /// 후기 사진. 목업에는 사진이 없어 회색 자리만 둔다.
    @ViewBuilder
    private var photo: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        if let name = review.photoName {
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: 107, height: 86)
                .clipShape(shape)
        } else {
            shape
                .fill(WeGoColor.placeholder)
                .frame(width: 107, height: 86)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
        }
    }
}

#Preview {
    CourseDetailView(
        course: MockData.previewCourse,
        startName: "여의나루역 1번출구 앞",
        endName: "여의도 한강공원 원효대교 남단",
        onBack: {}
    )
    .background(WeGoColor.surface)
}
