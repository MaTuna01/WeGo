import MapKit

/// 서버 API가 붙기 전까지 쓰는 목업 데이터. 좌표·잔여 대수·고도·후기는 실제 값이 아니다.
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
        Station(id: "TS-DDB", name: "갑천 대덕대교 남단", bikeOperator: .tashu,
                latitude: 36.37000, longitude: 127.39400, dockCount: 8,
                availableBikes: 2, updatedAt: Date().addingTimeInterval(-180)),
    ]

    /// 정류장에서 정류장까지의 공유·큐레이션 코스
    static let courses: [Course] = [
        makeCourse(
            id: "C-YN-HG", title: "원효대교 남단 강변길", from: "ST-YN-01", to: "ST-YD-HG",
            path: [(37.52710, 126.93290, 13), (37.52830, 126.93520, 12), (37.52930, 126.93780, 12),
                   (37.53010, 126.94050, 14), (37.53060, 126.94250, 13), (37.53070, 126.94370, 15)],
            waypoints: [CourseWaypoint(name: "물빛광장", pathIndex: 2)],
            bikeLanes: [0...5], likes: 42, rides: 128, saved: true, daysAgo: 20,
            reviews: [
                review("R-1", 5, "경치가 예뻐서 자전거 탈 맛 납니다", daysAgo: 2),
                review("R-2", 4, "평지라 아이랑 타기 좋아요", daysAgo: 6),
                review("R-3", 5, "해 질 녘에 꼭 타 보세요", daysAgo: 12),
            ]
        ),
        makeCourse(
            id: "C-YN-GH", title: "국회의사당 강변길", from: "ST-YN-01", to: "ST-GH-01",
            path: [(37.52710, 126.93290, 13), (37.52800, 126.93000, 12), (37.52900, 126.92700, 11),
                   (37.52960, 126.92400, 12), (37.52930, 126.92050, 15), (37.52840, 126.91760, 19)],
            waypoints: [CourseWaypoint(name: "여의도 마리나", pathIndex: 2)],
            bikeLanes: [0...3], likes: 18, rides: 55, daysAgo: 3,
            reviews: [
                review("R-4", 4, "마지막 오르막만 조금 힘들어요", daysAgo: 1),
                review("R-5", 5, "강바람 맞으며 달리기 최고", daysAgo: 4),
            ]
        ),
        makeCourse(
            id: "C-YN-SG", title: "샛강 생태공원 숲길", from: "ST-YN-01", to: "ST-YD-05",
            path: [(37.52710, 126.93290, 13), (37.52450, 126.93450, 11), (37.52150, 126.93300, 9),
                   (37.51900, 126.93000, 8), (37.51850, 126.92650, 9), (37.51950, 126.92480, 12),
                   (37.52150, 126.92430, 14)],
            waypoints: [CourseWaypoint(name: "샛강 생태공원", pathIndex: 3)],
            bikeLanes: [1...4], likes: 30, rides: 70, daysAgo: 10,
            reviews: [review("R-6", 5, "숲길이라 한여름에도 시원해요", daysAgo: 3)]
        ),
        makeCourse(
            id: "C-YN-YD5", title: "여의도공원 가로지르기", from: "ST-YN-01", to: "ST-YD-05",
            path: [(37.52710, 126.93290, 13), (37.52550, 126.93100, 14), (37.52400, 126.92880, 16),
                   (37.52280, 126.92650, 15), (37.52150, 126.92430, 14)],
            bikeLanes: [1...3], likes: 9, rides: 21, saved: true, daysAgo: 1
        ),
        makeCourse(
            id: "C-HG-YN", title: "여의나루역 강변길", from: "ST-YD-HG", to: "ST-YN-01",
            path: [(37.53070, 126.94370, 15), (37.53060, 126.94250, 13), (37.53010, 126.94050, 14),
                   (37.52930, 126.93780, 12), (37.52830, 126.93520, 12), (37.52710, 126.93290, 13)],
            waypoints: [CourseWaypoint(name: "물빛광장", pathIndex: 3)],
            bikeLanes: [0...5], likes: 12, rides: 33, daysAgo: 5
        ),
        makeCourse(
            id: "C-GH-YD5", title: "국회 둘레 평지 코스", from: "ST-GH-01", to: "ST-YD-05",
            path: [(37.52840, 126.91760, 19), (37.52620, 126.91820, 17), (37.52400, 126.91950, 15),
                   (37.52220, 126.92150, 14), (37.52150, 126.92430, 14)],
            likes: 7, rides: 15, saved: true, daysAgo: 7
        ),
        makeCourse(
            id: "C-EXPO-DDB", title: "갑천 자전거길", from: "TS-EXPO", to: "TS-DDB",
            path: [(36.37630, 127.38720, 42), (36.37450, 127.38950, 41), (36.37250, 127.39150, 41),
                   (36.37000, 127.39400, 43)],
            bikeLanes: [0...3], likes: 5, rides: 11, daysAgo: 2
        ),
    ]

    /// 홈 시트 "많이 찾는 코스"
    static var popularCourses: [Course] {
        Array(courses.sorted(by: isMorePopular).prefix(3))
    }

    /// 홈 시트 "나의 이용 기록". 주행 기록 저장이 생기면 실제 기록으로 바꾼다.
    static let myRides: [Course] = [
        Course(id: "R-01", title: "11/08 여의나루 출발", distanceMeters: 6_800, durationSeconds: 2_460),
        Course(id: "R-02", title: "11/02 한강 산책", distanceMeters: 3_900, durationSeconds: 1_320),
        Course(id: "R-03", title: "10/27 퇴근길", distanceMeters: 5_100, durationSeconds: 2_160),
    ]

    /// 정류장 시트의 코스 탭: 그 정류장에서 출발하는 코스
    static func courses(from station: Station, filter: CourseFilter) -> [Course] {
        let departing = courses.filter { $0.startStationID == station.id }
        switch filter {
        case .popular:
            return departing.sorted(by: isMorePopular)
        case .recent:
            return departing.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .saved:
            return departing.filter(\.isSaved)
        }
    }

    static func station(id: Station.ID?) -> Station? {
        stations.first { $0.id == id }
    }

    // MARK: - 만들기 도우미

    private static func isMorePopular(_ lhs: Course, _ rhs: Course) -> Bool {
        lhs.likeCount + lhs.rideCount > rhs.likeCount + rhs.rideCount
    }

    /// 경로 점으로 거리를 계산하고, 예상 시간은 따릉이 평균 속도(14km/h)에 도심 보정 ×1.2를 적용한다.
    private static func makeCourse(
        id: String,
        title: String,
        from: Station.ID,
        to: Station.ID,
        path: [(Double, Double, Double)],
        waypoints: [CourseWaypoint] = [],
        bikeLanes: [ClosedRange<Int>] = [],
        likes: Int,
        rides: Int,
        saved: Bool = false,
        daysAgo: Double,
        reviews: [CourseReview] = []
    ) -> Course {
        let points = path.map { CoursePoint(latitude: $0.0, longitude: $0.1, elevationMeters: $0.2) }
        let meters = zip(points, points.dropFirst()).reduce(0.0) { total, pair in
            let a = CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
            let b = CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude)
            return total + a.distance(from: b)
        }
        let averageSpeed = 14_000.0 / 3600 // m/s
        return Course(
            id: id,
            title: title,
            distanceMeters: Int(meters.rounded()),
            durationSeconds: Int((meters / averageSpeed * 1.2).rounded()),
            startStationID: from,
            endStationID: to,
            path: points,
            waypoints: waypoints,
            bikeLaneSegments: bikeLanes,
            reviews: reviews,
            likeCount: likes,
            rideCount: rides,
            isSaved: saved,
            createdAt: Date().addingTimeInterval(-daysAgo * 86_400)
        )
    }

    private static func review(_ id: String, _ rating: Int, _ text: String, daysAgo: Double) -> CourseReview {
        CourseReview(id: id, rating: rating, text: text, createdAt: Date().addingTimeInterval(-daysAgo * 86_400))
    }
}
