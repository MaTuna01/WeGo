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

/// 정류장 선택 후 시트 (Figma 299:121): 인기/최신/저장 코스 탭, 세로 코스 카드 목록, 코스 선택하기 / 대여하러 가기
/// 기획상 필요한 "잔여 대수(참고)"는 시안에 자리가 없어 아직 넣지 않았다 — 디자이너와 위치 결정 필요.
struct StationSheet: View {
    let station: Station
    @Binding var filter: CourseFilter
    let courses: [Course]
    /// 카드를 눌러 고른 코스(주황 테두리, 지도에 경로 표시)
    @Binding var selectedCourseID: Course.ID?
    /// `>`로 연 코스 상세. 있으면 목록 대신 상세를 보여준다(Figma 299:224).
    @Binding var detailCourseID: Course.ID?
    /// "코스 선택하기"로 이번 주행 코스로 지정한 코스
    let chosenCourseID: Course.ID?
    let onChooseCourse: () -> Void
    let onRent: () -> Void

    /// 하단 버튼 아래로 플로팅 탭바(58)와 여백(위 24, 아래 23)이 들어갈 자리
    private let tabBarReserve: CGFloat = 24 + 58 + 23

    var body: some View {
        BottomSheetContainer(handleTopPadding: 13) {
            VStack(alignment: .leading, spacing: 0) {
                if let detailCourse = courses.first(where: { $0.id == detailCourseID }) {
                    CourseDetailView(
                        course: detailCourse,
                        startName: startName(of: detailCourse),
                        endName: endName(of: detailCourse),
                        onBack: { detailCourseID = nil }
                    )
                    .padding(.top, 14)
                } else {
                    listContent
                }

                buttons
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, tabBarReserve)
            }
        }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(CourseFilter.allCases, id: \.self) { item in
                        PillChip(
                            title: item.title,
                            isSelected: filter == item,
                            width: 76,
                            height: 26,
                            background: WeGoColor.chip,
                            selectedBackground: WeGoColor.primaryLight,
                            selectedForeground: .black
                        ) {
                            filter = item
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 17)

                courseList
                    .padding(.top, 20)
        }
    }

    private func startName(of course: Course) -> String {
        MockData.station(id: course.startStationID)?.name ?? station.name
    }

    private func endName(of course: Course) -> String {
        MockData.station(id: course.endStationID)?.name ?? "도착 정류장"
    }

    @ViewBuilder
    private var courseList: some View {
        if courses.isEmpty {
            Text(filter == .saved ? "아직 저장한 코스가 없어요." : "이 정류장에서 출발한 코스가 아직 없어요.")
                .wegoFont(.regular, 13)
                .foregroundStyle(WeGoColor.gray500)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(courses) { course in
                        CourseRow(
                            course: course,
                            startName: startName(of: course),
                            endName: endName(of: course),
                            isSelected: selectedCourseID == course.id,
                            onDetail: {
                                selectedCourseID = course.id
                                detailCourseID = course.id
                            }
                        )
                        .onTapGesture { selectedCourseID = course.id }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    /// 173×52 버튼 두 개, 간격 16
    private var buttons: some View {
        HStack(spacing: 16) {
            // 지정 상태 디자인이 아직 없어 "선택됨" + 주황 배경으로 임시 구분한다.
            let isChosen = selectedCourseID != nil && selectedCourseID == chosenCourseID
            sheetButton(
                isChosen ? "선택됨" : "코스 선택하기",
                background: isChosen ? WeGoColor.primaryLight : WeGoColor.gray500,
                action: onChooseCourse
            )
            .disabled(selectedCourseID == nil)
            .accessibilityHint(isChosen ? "다시 누르면 코스 지정을 해제해요" : "대여 후 이 코스로 안내해요")
            sheetButton("대여하러 가기", background: WeGoColor.buttonDark, action: onRent)
                .accessibilityHint("\(station.bikeOperator.displayName) 앱으로 이동해 대여해요")
        }
    }

    private func sheetButton(_ title: String, background: Color, action: @escaping () -> Void) -> some View {
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
