import MapKit
import SwiftUI

/// 홈 = 지도(정류장 탐색). 정류장을 고르면 시트가 정류장 시트로 바뀐다.
///
/// 대여 흐름: "대여하러 가기" → 따릉이/타슈 앱 열기 → 우리 앱으로 돌아오면 "출발하기" 확인 → 라이딩 시작
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(MockData.defaultRegion))
    @State private var selectedStationID: Station.ID?
    @State private var operatorFilter: BikeOperator?
    @State private var courseFilter: CourseFilter = .popular
    @State private var selectedCourseID: Course.ID?
    @State private var detailCourseID: Course.ID?
    @State private var awaitingReturnFrom: Station?
    @State private var showDepartPrompt = false
    @State private var sheetDetent: SheetDetent = .standard
    // 아래 둘은 화면(global) 좌표. 지도는 화면 맨 위(상태 표시줄 뒤)부터 이 화면 아래끝까지 그려진다.
    /// 위 검색바·칩의 아래끝(시트를 펼쳤을 때 여기까지 올라온다)
    @State private var topBarBottom: CGFloat = 160
    /// 시트를 담는 영역(이 화면). 아래끝이 시트·지도의 아래끝이다.
    @State private var containerFrame: CGRect = .zero

    private var visibleStations: [Station] {
        MockData.stations.filter { operatorFilter == nil || $0.bikeOperator == operatorFilter }
    }

    private var selectedStation: Station? {
        MockData.stations.first { $0.id == selectedStationID }
    }

    private var stationCourses: [Course] {
        guard let selectedStation else { return [] }
        return MockData.courses(from: selectedStation, filter: courseFilter)
    }

    private var selectedCourse: Course? {
        stationCourses.first { $0.id == selectedCourseID }
    }

    var body: some View {
        ZStack(alignment: .top) {
            StationMapView(
                stations: visibleStations,
                selectedID: $selectedStationID,
                position: $camera,
                course: selectedCourse
            )
            .ignoresSafeArea()

            MapTopBar(
                title: selectedStation?.name,
                operatorFilter: $operatorFilter,
                onClear: { selectedStationID = nil },
                onRecenter: {
                    withAnimation { camera = .userLocation(fallback: .region(MockData.defaultRegion)) }
                }
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { topBarBottom = $0 }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { containerFrame = $0 }
        .overlay(alignment: .bottom) {
            sheet
        }
        .animation(.spring(duration: 0.3), value: selectedStationID)
        .onAppear {
            appState.location.requestPermission()
        }
        .onChange(of: selectedStationID) { _, newID in
            sheetDetent = .standard
            selectFirstCourse()
            // 다른 정류장으로 바꾸면 그 정류장에서 출발하지 않는 지정 코스는 풀어 준다.
            if appState.plannedCourse?.startStationID != newID {
                appState.plannedCourse = nil
            }
        }
        .onChange(of: courseFilter) { _, _ in
            selectFirstCourse()
        }
        .onChange(of: selectedCourseID) { _, _ in
            fitSelectedCourse()
        }
        .onChange(of: detailCourseID) { _, newID in
            // 코스 상세로 들어가면 기본 높이에서 시작
            if newID != nil { sheetDetent = .standard }
        }
        .onChange(of: sheetDetent) { _, _ in
            // 시트 높이가 바뀌면 보이는 지도 영역도 바뀌므로 코스를 다시 맞춘다.
            if selectedStation != nil { fitSelectedCourse() }
        }
        .onChange(of: operatorFilter) { _, _ in
            if let selectedStation, !visibleStations.contains(selectedStation) {
                selectedStationID = nil
            }
        }
        .onReturnFromOperatorApp(isAwaiting: awaitingReturnFrom != nil) {
            showDepartPrompt = true
        }
        .alert("대여를 마쳤나요?", isPresented: $showDepartPrompt, presenting: awaitingReturnFrom) { station in
            Button("출발하기") {
                awaitingReturnFrom = nil
                selectedStationID = nil
                appState.startRide(from: station, pass: .oneHour, course: appState.plannedCourse)
            }
            Button("아직이에요", role: .cancel) {
                awaitingReturnFrom = nil
            }
        } message: { station in
            Text(departMessage(for: station))
        }
    }

    @ViewBuilder
    private var sheet: some View {
        if let station = selectedStation {
            StationSheet(
                station: station,
                filter: $courseFilter,
                courses: stationCourses,
                selectedCourseID: $selectedCourseID,
                detailCourseID: $detailCourseID,
                chosenCourseID: appState.plannedCourse?.id,
                onChooseCourse: toggleChosenCourse,
                onRent: { rent(at: station) },
                detent: $sheetDetent,
                heights: stationSheetHeights
            )
            .transition(.move(edge: .bottom))
        } else {
            HomeSheet(
                popularCourses: MockData.popularCourses,
                myRides: MockData.myRides,
                detent: $sheetDetent,
                heights: homeSheetHeights
            )
            .transition(.move(edge: .bottom))
        }
    }

    /// 접힘: 플로팅 탭바(아래 여백 23 + 높이 58) 위로 손잡이만 보이게
    private static let collapsedSheetHeight: CGFloat = 23 + 58 + 24

    /// 홈 시트: 기본은 Figma 높이 372pt(299:58, 위에서 502pt부터)
    private func homeSheetHeights(_ containerHeight: CGFloat) -> SheetHeights {
        SheetHeights(
            collapsed: Self.collapsedSheetHeight,
            standard: 372,
            expanded: expandedSheetHeight(containerHeight)
        )
    }

    /// 정류장 시트 접힘: 손잡이(위 13 + 5) + 버튼 위 여백 12 + 버튼 52 + 탭바 자리(24 + 58 + 23).
    /// 하단 버튼은 어느 높이에서든 보여야 해서 홈 시트보다 높다.
    private static let stationCollapsedSheetHeight: CGFloat = 13 + 5 + 12 + 52 + 24 + 58 + 23

    /// 정류장·코스 상세 시트: 기본은 Figma 299:121·299:224처럼 화면 위에서 365pt(874pt 기준)부터
    private func stationSheetHeights(_ containerHeight: CGFloat) -> SheetHeights {
        SheetHeights(
            collapsed: Self.stationCollapsedSheetHeight,
            standard: screenHeight(containerHeight) * (874 - 365) / 874,
            expanded: expandedSheetHeight(containerHeight)
        )
    }

    /// 펼침: 위 검색바·칩 아래 12pt까지
    private func expandedSheetHeight(_ containerHeight: CGFloat) -> CGFloat {
        guard containerFrame.height > 0 else { return containerHeight * 0.85 }
        return containerFrame.maxY - topBarBottom - 12
    }

    /// Figma 프레임(874pt)과 비교할 화면 전체 높이 = 지도 높이(화면 맨 위 ~ 이 화면 아래끝)
    private func screenHeight(_ containerHeight: CGFloat) -> CGFloat {
        containerFrame.maxY > 0 ? containerFrame.maxY : containerHeight
    }

    /// 선택한 코스가 위 칩과 시트 사이 지도 영역에 들어오도록 카메라를 옮긴다.
    private func fitSelectedCourse() {
        guard let selectedCourse, containerFrame.height > 0 else { return }
        let mapHeight = containerFrame.maxY
        let sheetTop = mapHeight - stationSheetHeights(containerFrame.height).height(for: sheetDetent)
        // 선택한 정류장 핀이 좌표 위로 약 75pt 솟아 있어 위쪽은 그만큼 더 비운다. 아래는 시트에서 10pt 띄운다.
        let top = (topBarBottom + 75) / mapHeight
        let bottom = (sheetTop - 10) / mapHeight
        // 시트를 펼쳐 지도가 거의 안 보이면 카메라는 그대로 둔다.
        guard bottom - top > 0.08,
              let region = StationMapView.region(fitting: selectedCourse, visibleTop: top, visibleBottom: bottom)
        else { return }
        withAnimation { camera = .region(region) }
    }

    /// 정류장이나 코스 탭이 바뀌면 첫 코스를 골라 둔다(디자인처럼 첫 카드가 선택된 상태로 시작).
    private func selectFirstCourse() {
        selectedCourseID = stationCourses.first?.id
        detailCourseID = nil
    }

    /// 고른 카드를 이번 주행 코스로 지정하거나, 이미 지정돼 있으면 해제한다.
    private func toggleChosenCourse() {
        guard let selectedCourse else { return }
        appState.plannedCourse = appState.plannedCourse?.id == selectedCourse.id ? nil : selectedCourse
    }

    private func departMessage(for station: Station) -> String {
        let base = "\(station.bikeOperator.displayName) 앱에서 대여했다면 출발을 눌러 주세요. 1시간권 기준으로 타이머가 시작돼요."
        guard let course = appState.plannedCourse, course.startStationID == station.id else { return base }
        return base + "\n'\(course.title)' 코스로 안내해요."
    }

    private func rent(at station: Station) {
        awaitingReturnFrom = station
        // 시뮬레이터처럼 다른 앱을 못 여는 환경에서는 바로 출발 확인을 띄운다.
        RentalAppLauncher.open(station.bikeOperator, using: openURL) { showDepartPrompt = true }
    }
}

#Preview {
    let state = AppState()
    return HomeView()
        .environment(state)
        .environment(state.location)
}
