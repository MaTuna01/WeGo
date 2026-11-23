import SwiftData
import SwiftUI

/// 정류장 선택 전 홈 시트 (Figma 299:58): 나의 이용 기록. 끌어서 높이를 바꾼다.
/// 디자인의 "많이 찾는 코스"는 다른 사람의 공유 경로가 필요해서 서버 연동(1.1) 때 다시 넣는다.
struct HomeSheet: View {
    @Environment(\.tabBarHeight) private var tabBarHeight
    /// 최근 주행 기록(최대 3개, 최신순)
    let myRides: [RideRecord]
    @Binding var detent: SheetDetent
    let heights: (CGFloat) -> SheetHeights

    var body: some View {
        DraggableBottomSheet(detent: $detent, heights: heights) {
            SheetScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitle("나의 이용 기록")
                        .padding(.top, 15)
                    if myRides.isEmpty {
                        emptyText("첫 라이딩을 마치면 기록이 여기에 쌓여요.")
                            .padding(.top, 7)
                    } else {
                        rideRow(myRides)
                            .padding(.top, 7)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, tabBarHeight + 24) // 탭바에 가리지 않게
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .wegoFont(.regular, 14, tracking: -0.7)
            .foregroundStyle(.black)
    }

    private func rideRow(_ rides: [RideRecord]) -> some View {
        HStack(spacing: 20) {
            ForEach(rides.prefix(3)) { ride in
                CourseCard(title: ride.cardTitle, subtitle: ride.cardSubtitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 116)
            }
            // 3개보다 적으면 빈 자리를 둬서 카드 폭을 그대로 유지한다.
            ForEach(0..<max(0, 3 - rides.count), id: \.self) { _ in
                Color.clear
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
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    /// 저장, 즐겨찾기 표시(카드 배지)
    @Query private var savedCourses: [SavedCourse]
    let station: Station
    @Binding var filter: CourseFilter
    let courses: [Course]
    /// 카드를 눌러 고른 코스(주황 테두리, 지도에 경로 표시)
    @Binding var selectedCourseID: Course.ID?
    /// 선택된 카드를 다시 눌러 연 코스 상세. 있으면 목록 대신 상세를 보여준다(Figma 299:224).
    @Binding var detailCourseID: Course.ID?
    /// "코스 선택하기"로 이번 주행 코스로 지정한 코스
    let chosenCourseID: Course.ID?
    let onChooseCourse: () -> Void
    let onRent: () -> Void
    @Binding var detent: SheetDetent
    let heights: (CGFloat) -> SheetHeights

    @Environment(\.tabBarHeight) private var tabBarHeight
    /// 하단 버튼과 탭바 사이 여백
    static let buttonBottomGap: CGFloat = 16

    var body: some View {
        // 하단 버튼은 어느 높이에서든 보여야 해서, 접힐 때는 위쪽 목록·상세만 흐리게 하고 줄여서 가린다.
        DraggableBottomSheet(detent: $detent, handleTopPadding: 13, fadesContentWhenCollapsed: false, heights: heights) {
            VStack(alignment: .leading, spacing: 0) {
                Group {
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
                }
                // 접힘에서는 0까지 줄어들어 버튼을 밀어내지 않게 한다.
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
                .clipped()
                .fadesWhenSheetCollapses()

                buttons
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, Self.buttonBottomGap + tabBarHeight)
            }
        }
    }

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(CourseFilter.available, id: \.self) { item in
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
        appState.stationRepository.station(id: course.startStationID)?.name ?? station.name
    }

    private func endName(of course: Course) -> String {
        appState.stationRepository.station(id: course.endStationID)?.name ?? "도착 정류장"
    }

    @ViewBuilder
    private var courseList: some View {
        if courses.isEmpty {
            Text(emptyMessage)
                .wegoFont(.regular, 13)
                .foregroundStyle(WeGoColor.gray500)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            SheetScrollView {
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
                            },
                            marks: marks(for: course.id),
                            onToggleMark: { mark in toggle(mark, for: course) }
                        )
                        .onTapGesture { tapCourse(course.id) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
    }

    /// 탭별 빈 상태 문구. 1.0은 최신 탭만 보인다(CourseFilter.available).
    private var emptyMessage: String {
        switch filter {
        case .recent: "이 정류장에서 출발한 내 기록이 아직 없어요.\n정류장에서 정류장까지 달리면 여기에 쌓여요."
        case .popular: "인기 코스는 준비 중이에요."
        case .saved: "이 정류장에서 출발하는 저장한 코스가 없어요.\n코스 카드의 북마크나 별을 눌러 저장해 보세요."
        }
    }

    private func marks(for courseID: Course.ID) -> Set<CourseMark> {
        guard let saved = savedCourses.first(where: { $0.courseID == courseID }) else { return [] }
        return Set(CourseMark.allCases.filter { saved.has($0) })
    }

    private func toggle(_ mark: CourseMark, for course: Course) {
        SavedCourse.toggle(
            mark,
            for: course,
            startStationName: startName(of: course),
            endStationName: endName(of: course),
            in: modelContext
        )
    }

    /// 처음 누르면 선택(지도에 경로), 이미 선택된 카드를 다시 누르면 코스 상세로 간다.
    private func tapCourse(_ id: Course.ID) {
        if selectedCourseID == id {
            detailCourseID = id
        } else {
            selectedCourseID = id
        }
    }

    /// 173x52 버튼 두 개, 간격 16. 문구는 목록(Figma 402:159)과 코스 상세(299:224)가 다르다.
    private var buttons: some View {
        HStack(spacing: 16) {
            // 지정 상태 디자인이 아직 없어 "선택됨" + 주황 배경으로 임시 구분한다.
            let isChosen = selectedCourseID != nil && selectedCourseID == chosenCourseID
            let isDetail = detailCourseID != nil
            sheetButton(
                isChosen ? "선택됨" : (isDetail ? "코스 선택" : "코스 선택하기"),
                background: isChosen ? WeGoColor.primaryLight : WeGoColor.gray500,
                action: onChooseCourse
            )
            .disabled(selectedCourseID == nil)
            .accessibilityHint(isChosen ? "다시 누르면 코스 지정을 해제해요" : "대여 후 이 코스로 안내해요")
            sheetButton(isDetail ? "대여하기" : "대여하러 가기", background: WeGoColor.buttonDark, action: onRent)
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
