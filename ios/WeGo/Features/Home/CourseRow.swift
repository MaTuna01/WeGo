import SwiftUI

/// 정류장 시트의 코스 카드(362x125, Figma 402:306, 카드 시안 359:1168).
/// 왼쪽: 코스 썸네일(사진, 없으면 경로 지도), 오른쪽: 코스 이름, 거리와 예상 시간, 출발 -> 도착 정류장.
/// 선택된 카드는 주황 테두리. 이미 선택된 카드를 한 번 더 누르면 코스 상세로 간다(정류장 시트가 처리).
/// 디자인의 오른쪽 위 북마크, 별 배지는 저장 기능(#48)과 함께 넣는다.
struct CourseRow: View {
    let course: Course
    let startName: String
    let endName: String
    var isSelected = false
    var onDetail: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 19) {
            CourseThumbnail(course: course)
                .frame(width: CourseThumbnailStyle.size.width, height: CourseThumbnailStyle.size.height)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    if course.isMyRide {
                        MyRideBadge()
                    }
                    Text(course.title)
                        .wegoFont(.medium, 16, tracking: -0.4)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                }
                .padding(.top, 4)

                stats
                    .padding(.top, 10)

                route
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.top, 15)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 125, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(WeGoColor.primaryLight, lineWidth: 1)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: "코스 상세 보기") { onDetail?() }
    }

    /// "701m 약 12분": 숫자는 크게 주황, 단위는 작게 회색. 예상 시간이라 "약"을 붙인다(도메인 규칙).
    private var stats: some View {
        let distance = CourseRow.distanceParts(course.distanceMeters)
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            number(distance.value)
            unit(distance.unit)
                .padding(.trailing, 8)
            unit("약 ")
            number("\(CourseRow.approxMinutes(course.durationSeconds))")
            unit("분")
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func number(_ text: String) -> some View {
        Text(text)
            .wegoFont(.bold, 24, tracking: -0.5)
            .foregroundStyle(WeGoColor.primary)
    }

    private func unit(_ text: String) -> some View {
        Text(text)
            .wegoFont(.regular, 13)
            .foregroundStyle(WeGoColor.gray500)
    }

    /// 출발 -> 도착 정류장(이름이 길면 줄임)
    private var route: some View {
        HStack(spacing: 6) {
            Text(startName)
                .lineLimit(1)
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(WeGoColor.gray500)
            Text(endName)
                .lineLimit(1)
        }
        .wegoFont(.regular, 12, tracking: -0.5)
        .foregroundStyle(.black)
    }

    private var accessibilityText: String {
        let prefix = course.isMyRide ? "내 기록, " : ""
        let distance = WeGoFormat.distance(course.distanceMeters)
        let minutes = WeGoFormat.approxMinutes(course.durationSeconds)
        return "\(prefix)\(course.title), \(distance), \(minutes), \(startName)에서 \(endName)까지"
    }
}

extension CourseRow {
    /// 850m -> ("850", "m"), 1234m -> ("1.2", "km")
    static func distanceParts(_ meters: Int) -> (value: String, unit: String) {
        meters >= 1000
            ? (String(format: "%.1f", Double(meters) / 1000), "km")
            : ("\(max(0, meters))", "m")
    }

    /// 예상 시간(분, 반올림, 최소 1분). WeGoFormat.approxMinutes와 같은 규칙
    static func approxMinutes(_ seconds: Int) -> Int {
        max(1, Int((Double(seconds) / 60).rounded()))
    }
}

#Preview {
    let course = MockData.previewCourse
    VStack(spacing: 12) {
        CourseRow(course: course, startName: "여의나루역 1번출구 앞", endName: "여의도 한강공원 원효대교 남단", isSelected: true)
        CourseRow(course: course, startName: "서울숲", endName: "서울 한강공원")
    }
    .padding(20)
    .background(WeGoColor.surface)
}

/// 내 주행 기록에서 만든 코스 표시. 디자인이 없어 임시 모양(연한 주황 캡슐)이다.
struct MyRideBadge: View {
    var body: some View {
        Text("내 기록")
            .wegoFont(.medium, 11, tracking: -0.3)
            .foregroundStyle(WeGoColor.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(WeGoColor.peach, in: Capsule())
            .fixedSize()
    }
}
