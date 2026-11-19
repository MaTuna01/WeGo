import MapKit

/// 지도 기본 위치와 Xcode 미리보기용 예시. 정류장 목록은 StationRepository(앱 내장 목록: Resources/Stations)가 맡는다.
enum MockData {
    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5270, longitude: 126.9300),
        span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
    )

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
