import SwiftUI

/// 코스 상세 (Figma 299:224). 정류장 시트 안에서 코스 카드의 `>`로 들어온다.
/// 위에서부터: 출발 → 도착 카드(왼쪽 위 뒤로가기), 경사도, 코스 정보, 사용자 후기.
/// 하단 "코스 선택하기 / 대여하러 가기" 버튼은 정류장 시트가 목록과 같이 붙여 준다.
struct CourseDetailView: View {
    let course: Course
    let startName: String
    let endName: String
    let onBack: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                CourseRow(course: course, startName: startName, endName: endName)
                    .overlay(alignment: .topLeading) { backButton }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
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

#Preview {
    CourseDetailView(
        course: MockData.courses[0],
        startName: "여의나루역 1번출구 앞",
        endName: "여의도 한강공원 원효대교 남단",
        onBack: {}
    )
    .background(WeGoColor.surface)
}
