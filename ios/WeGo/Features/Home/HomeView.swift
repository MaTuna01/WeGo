import MapKit
import SwiftData
import SwiftUI

/// 홈 = 지도(정류장 탐색). 정류장을 고르면 시트가 정류장 시트로 바뀐다.
///
/// 대여 흐름: "대여하러 가기" → 따릉이/타슈 앱 열기 → 우리 앱으로 돌아오면 "출발하기" 확인 → 라이딩 시작
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.tabBarHeight) private var tabBarHeight

    /// 홈 "나의 이용 기록": 최근 주행 3개
    @Query(HomeView.recentRidesDescriptor) private var recentRides: [RideRecord]

    private static var recentRidesDescriptor: FetchDescriptor<RideRecord> {
        var descriptor = FetchDescriptor<RideRecord>(sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
        descriptor.fetchLimit = 3
        return descriptor
    }

    /// 정류장 시트 최신 탭에 섞어 보여줄 내 공유 가능 기록
    @Query(filter: #Predicate<RideRecord> { $0.isShareable == true }, sort: \RideRecord.endedAt, order: .reverse)
    private var shareableRides: [RideRecord]
    /// 고른 정류장에서 출발한 내 기록을 코스로 만든 것. 경로 압축을 매번 풀지 않게 정류장·기록이 바뀔 때만 다시 만든다.
    @State private var myRideCourses: [Course] = []

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(MockData.defaultRegion))
    @State private var selectedStationID: Station.ID?
    @State private var operatorFilter: BikeOperator?
    /// 1.0은 인기/저장 코스가 없어서(서버 공유 경로 전) 내 기록이 나오는 최신 탭을 기본으로 연다.
    @State private var courseFilter: CourseFilter = .recent
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
    /// 지도에 보이는 영역. 첫 카메라 이동 전에는 기본 위치로 본다.
    @State private var mapRegion: MKCoordinateRegion = MockData.defaultRegion

    /// 운영사 칩으로 거른 전체 정류장
    private var filteredStations: [Station] {
        appState.stationRepository.stations.filter { operatorFilter == nil || $0.bikeOperator == operatorFilter }
    }

    /// 지도에 실제로 그리는 정류장(보이는 영역 근처, 개수 제한)
    private var mapStations: StationMapFilter.Result {
        StationMapFilter.stations(filteredStations, in: mapRegion, selectedID: selectedStationID)
    }

    private var selectedStation: Station? {
        appState.stationRepository.station(id: selectedStationID)
    }

    /// 정류장 시트 코스 목록. 1.0은 서버 공유 경로가 없어서, 최신 탭에 이 정류장에서 출발한 내 기록만 보여준다.
    private var stationCourses: [Course] {
        guard let selectedStation else { return [] }
        guard selectedStation != nil else { return [] }
        switch courseFilter {
        case .recent:
            return myRideCourses
        case .popular, .saved:
            // 인기(다른 사람의 공유 경로)와 저장은 서버 연동(1.1) 후에 채운다.
            return []
        }
    }

    private var selectedCourse: Course? {
        stationCourses.first { $0.id == selectedCourseID }
    }

    var body: some View {
        let shown = mapStations
        ZStack(alignment: .top) {
            StationMapView(
                stations: shown.stations,
                selectedID: $selectedStationID,
                position: $camera,
                course: selectedCourse,
                onRegionChange: { mapRegion = $0 }
            )
            .ignoresSafeArea()

            if shown.isZoomedOutTooFar {
                MapZoomHint()
                    .padding(.top, topBarBottom - containerFrame.minY + 12)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

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
        .animation(.easeInOut(duration: 0.2), value: mapStations.isZoomedOutTooFar)
        .onAppear {
            appState.location.requestPermission()
        }
        .onChange(of: selectedStationID) { _, newID in
            sheetDetent = .standard
            refreshMyRideCourses()
            selectFirstCourse()
            // 다른 정류장으로 바꾸면 그 정류장에서 출발하지 않는 지정 코스는 풀어 준다.
            if appState.plannedCourse?.startStationID != newID {
                appState.plannedCourse = nil
            }
        }
        .onChange(of: shareableRides.map(\.id)) { _, _ in
            refreshMyRideCourses()
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
            if let selectedStation, !filteredStations.contains(selectedStation) {
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
                myRides: recentRides,
                detent: $sheetDetent,
                heights: homeSheetHeights
            )
            .transition(.move(edge: .bottom))
        }
    }

    /// 접힘: 탭바 위로 손잡이만 보이게
    private var collapsedSheetHeight: CGFloat { tabBarHeight + 24 }

    /// 홈 시트: 기본은 Figma 높이 372pt(299:58, 위에서 502pt부터)
    private func homeSheetHeights(_ containerHeight: CGFloat) -> SheetHeights {
        SheetHeights(
            collapsed: collapsedSheetHeight,
            standard: 372,
            expanded: expandedSheetHeight(containerHeight)
        )
    }

    /// 정류장 시트 접힘: 손잡이(위 13 + 5) + 버튼 위 여백 12 + 버튼 52 + 버튼 아래 여백 + 탭바.
    /// 하단 버튼은 어느 높이에서든 보여야 해서 홈 시트보다 높다.
    private var stationCollapsedSheetHeight: CGFloat {
        13 + 5 + 12 + 52 + StationSheet.buttonBottomGap + tabBarHeight
    }

    /// 정류장·코스 상세 시트: 기본은 Figma 299:121·299:224처럼 화면 위에서 365pt(874pt 기준)부터
    private func stationSheetHeights(_ containerHeight: CGFloat) -> SheetHeights {
        SheetHeights(
            collapsed: stationCollapsedSheetHeight,
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

    private func refreshMyRideCourses() {
        guard let selectedStationID else {
            myRideCourses = []
            return
        }
        myRideCourses = shareableRides.shareable(departingFrom: selectedStationID).compactMap { $0.makeCourse() }
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
        .modelContainer(state.rideRecords.container)
}
