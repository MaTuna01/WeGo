import MapKit
import SwiftUI

/// 홈 = 지도(정류장 탐색). 정류장을 고르면 시트가 정류장 시트로 바뀐다.
///
/// 대여 흐름: "대여하러 가기" → 따릉이/타슈 앱 열기 → 우리 앱으로 돌아오면 "출발하기" 확인 → 라이딩 시작
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(MockData.defaultRegion))
    @State private var selectedStationID: Station.ID?
    @State private var operatorFilter: BikeOperator?
    @State private var courseFilter: CourseFilter = .popular
    @State private var awaitingReturnFrom: Station?
    @State private var showDepartPrompt = false

    private var visibleStations: [Station] {
        MockData.stations.filter { operatorFilter == nil || $0.bikeOperator == operatorFilter }
    }

    private var selectedStation: Station? {
        MockData.stations.first { $0.id == selectedStationID }
    }

    var body: some View {
        ZStack(alignment: .top) {
            StationMapView(stations: visibleStations, selectedID: $selectedStationID, position: $camera)
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
        }
        .overlay(alignment: .bottom) {
            sheet
        }
        .animation(.spring(duration: 0.3), value: selectedStationID)
        .onAppear {
            appState.location.requestPermission()
        }
        .onChange(of: operatorFilter) { _, _ in
            if let selectedStation, !visibleStations.contains(selectedStation) {
                selectedStationID = nil
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, awaitingReturnFrom != nil {
                showDepartPrompt = true
            }
        }
        .alert("대여를 마쳤나요?", isPresented: $showDepartPrompt, presenting: awaitingReturnFrom) { station in
            Button("출발하기") {
                awaitingReturnFrom = nil
                selectedStationID = nil
                appState.startRide(from: station, pass: .oneHour)
            }
            Button("아직이에요", role: .cancel) {
                awaitingReturnFrom = nil
            }
        } message: { station in
            Text("\(station.bikeOperator.displayName) 앱에서 대여했다면 출발을 눌러 주세요. 1시간권 기준으로 타이머가 시작돼요.")
        }
    }

    @ViewBuilder
    private var sheet: some View {
        if let station = selectedStation {
            StationSheet(
                station: station,
                filter: $courseFilter,
                courses: MockData.courses(for: courseFilter),
                onRent: { rent(at: station) }
            )
            .frame(height: 361)
            .transition(.move(edge: .bottom))
        } else {
            HomeSheet(popularCourses: MockData.popularCourses, myRides: MockData.myRides)
                .frame(height: 372)
                .transition(.move(edge: .bottom))
        }
    }

    private func rent(at station: Station) {
        awaitingReturnFrom = station
        openURL(RentalAppLauncher.url(for: station.bikeOperator)) { accepted in
            // 시뮬레이터처럼 다른 앱을 못 여는 환경에서는 바로 출발 확인을 띄운다.
            if !accepted { showDepartPrompt = true }
        }
    }
}

#Preview {
    let state = AppState()
    return HomeView()
        .environment(state)
        .environment(state.location)
}
