import MapKit

/// 서버 API가 붙기 전까지 쓰는 목업 데이터. 좌표·잔여 대수는 실제 값이 아니다.
enum MockData {
    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5270, longitude: 126.9300),
        span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
    )

    static let stations: [Station] = [
        Station(id: "ST-YN-01", name: "여의나루역 1번출구 앞", bikeOperator: .ttareungyi,
                latitude: 37.52710, longitude: 126.93290, dockCount: 15,
                availableBikes: 3, updatedAt: Date().addingTimeInterval(-120)),
        Station(id: "ST-YD-HG", name: "여의도 한강공원 원효대교 남단", bikeOperator: .ttareungyi,
                latitude: 37.53070, longitude: 126.94370, dockCount: 20,
                availableBikes: 7, updatedAt: Date().addingTimeInterval(-60)),
        Station(id: "ST-GH-01", name: "국회의사당역 1번출구", bikeOperator: .ttareungyi,
                latitude: 37.52840, longitude: 126.91760, dockCount: 12,
                availableBikes: nil, updatedAt: nil),
        Station(id: "ST-YD-05", name: "여의도역 5번출구", bikeOperator: .ttareungyi,
                latitude: 37.52150, longitude: 126.92430, dockCount: 10,
                availableBikes: 1, updatedAt: Date().addingTimeInterval(-300)),
        Station(id: "TS-EXPO", name: "엑스포다리 남단", bikeOperator: .tashu,
                latitude: 36.37630, longitude: 127.38720, dockCount: 10,
                availableBikes: 4, updatedAt: Date().addingTimeInterval(-90)),
    ]

    static let popularCourses: [Course] = [
        Course(id: "C-01", title: "여의도 한강 한바퀴", distanceMeters: 8_400, durationSeconds: 2_400),
        Course(id: "C-02", title: "샛강 생태공원 숲길", distanceMeters: 4_250, durationSeconds: 1_380),
        Course(id: "C-03", title: "원효대교 → 마포대교", distanceMeters: 3_100, durationSeconds: 960),
    ]

    static let recentCourses: [Course] = [
        Course(id: "C-04", title: "국회 둘레 평지 코스", distanceMeters: 2_800, durationSeconds: 900),
        Course(id: "C-05", title: "여의나루 → 노들섬", distanceMeters: 5_600, durationSeconds: 1_800),
    ]

    static let savedCourses: [Course] = []

    static let myRides: [Course] = [
        Course(id: "R-01", title: "11/08 여의나루 출발", distanceMeters: 6_800, durationSeconds: 2_460),
        Course(id: "R-02", title: "11/02 한강 산책", distanceMeters: 3_900, durationSeconds: 1_320),
        Course(id: "R-03", title: "10/27 퇴근길", distanceMeters: 5_100, durationSeconds: 2_160),
    ]

    static func courses(for filter: CourseFilter) -> [Course] {
        switch filter {
        case .popular: popularCourses
        case .recent: recentCourses
        case .saved: savedCourses
        }
    }
}
