import SwiftUI

/// 정류장 선택 전 홈 시트 (Figma 143:528): 많이 찾는 코스 / 나의 이용 기록
struct HomeSheet: View {
    let popularCourses: [Course]
    let myRides: [Course]

    var body: some View {
        BottomSheetContainer {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitle("많이 찾는 코스")
                        .padding(.top, 15)
                    cardRow(popularCourses)
                        .padding(.top, 7)

                    sectionTitle("나의 이용 기록")
                        .padding(.top, 15)
                    if myRides.isEmpty {
                        emptyText("첫 라이딩을 마치면 기록이 여기에 쌓여요.")
                            .padding(.top, 7)
                    } else {
                        cardRow(myRides)
                            .padding(.top, 7)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120) // 플로팅 탭바에 가리지 않게
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .wegoFont(.regular, 14, tracking: -0.7)
            .foregroundStyle(.black)
    }

    private func cardRow(_ courses: [Course]) -> some View {
        HStack(spacing: 20) {
            ForEach(courses.prefix(3)) { course in
                CourseCard(course: course)
                    .frame(maxWidth: .infinity)
                    .frame(height: 116)
            }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .wegoFont(.regular, 13)
            .foregroundStyle(WeGoColor.gray500)
            .frame(maxWidth: .infinity, minHeight: 116)
    }
}

/// 정류장 선택 후 시트 (Figma 143:458): 인기/최신/저장 코스 + 대여하러 가기
/// 기획상 필요한 "잔여 대수(참고)"는 시안에 자리가 없어 아직 넣지 않았다 — 디자이너와 위치 결정 필요.
struct StationSheet: View {
    let station: Station
    @Binding var filter: CourseFilter
    let courses: [Course]
    let onRent: () -> Void

    var body: some View {
        BottomSheetContainer(handleTopPadding: 13) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(CourseFilter.allCases, id: \.self) { item in
                        PillChip(title: item.title, isSelected: filter == item, width: 76, height: 26, background: WeGoColor.chip) {
                            filter = item
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 17)

                Group {
                    if courses.isEmpty {
                        Text(filter == .saved ? "아직 저장한 코스가 없어요." : "이 정류장에서 출발한 코스가 아직 없어요.")
                            .wegoFont(.regular, 13)
                            .foregroundStyle(WeGoColor.gray500)
                            .frame(maxWidth: .infinity)
                            .frame(height: 103)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(courses) { course in
                                    CourseCard(course: course, showsMenu: true)
                                        .frame(width: 159, height: 103)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.top, 15)

                Button(action: onRent) {
                    Text("대여하러 가기")
                        .wegoFont(.bold, 18)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(WeGoColor.buttonDark, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .accessibilityHint("\(station.bikeOperator.displayName) 앱으로 이동해 대여해요")

                Spacer(minLength: 0)
            }
        }
    }
}
