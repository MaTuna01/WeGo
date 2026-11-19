import MapKit

/// 서버 API가 붙기 전까지 쓰는 목업 정류장. 잔여 대수는 실제 값이 아니다.
/// 좌표는 실제 정류장 위치가 아니지만, 지도에서 강 위에 찍히지 않도록 육지(공원, 도로) 위로 맞춰 두었다.
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
                latitude: 37.52320, longitude: 126.93920, dockCount: 20,
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
        Station(id: "TS-DDB", name: "갑천 대덕대교 남단", bikeOperator: .tashu,
                latitude: 36.37000, longitude: 127.39400, dockCount: 8,
                availableBikes: 2, updatedAt: Date().addingTimeInterval(-180)),
    ]

    static func station(id: Station.ID?) -> Station? {
        stations.first { $0.id == id }
    }

    /// Xcode 미리보기 전용 예시 코스(여의나루역 -> 원효대교 남단). 화면 데이터로는 쓰지 않는다.
    /// 1.0은 목업 코스, 후기, 인기 수치를 보여주지 않는다(심사 가이드라인 2.1, 2.3). 코스 목록에는 내 기록만 나온다.
    static let previewCourse: Course = {
        let path = [(37.52710, 126.93290, 13.0), (37.52620, 126.93400, 12.0), (37.52540, 126.93520, 12.0),
                    (37.52460, 126.93660, 14.0), (37.52390, 126.93790, 13.0), (37.52320, 126.93920, 15.0)]
        var course = Course(id: "PREVIEW", title: "여의도 한강공원 원효대교 남단", distanceMeters: 707, durationSeconds: 218)
        course.startStationID = "ST-YN-01"
        course.endStationID = "ST-YD-HG"
        course.path = path.map { CoursePoint(latitude: $0.0, longitude: $0.1, elevationMeters: $0.2) }
        return course
    }()
}
