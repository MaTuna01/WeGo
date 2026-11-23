import CoreLocation
import Foundation

enum BikeOperator: String, CaseIterable, Hashable {
    case ttareungyi
    case tashu

    var displayName: String {
        switch self {
        case .ttareungyi: "따릉이"
        case .tashu: "타슈"
        }
    }

    /// 1.0에서 지원하는 운영사. 서버가 따릉이만 내려주므로 타슈 필터를 보여주면 빈 지도가 된다.
    /// 운영사가 하나뿐이면 홈의 운영사 필터 칩을 숨긴다(MapTopBar).
    static let available: [BikeOperator] = [.ttareungyi]
}

/// 공유자전거 정류장. 서버의 공통 Station 모델(운영사별 어댑터로 변환된 값)에 대응한다.
struct Station: Identifiable, Hashable {
    let id: String
    let name: String
    let bikeOperator: BikeOperator
    let latitude: Double
    let longitude: Double
    let dockCount: Int
    /// 공공 API 기준 잔여 대수. 신뢰도가 낮으므로 단정하지 말고 "앱 기준 3대 · 2분 전"처럼 참고값으로만 쓴다. nil = 정보 없음
    let availableBikes: Int?
    let updatedAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// 정류장에서 정류장까지의 코스. 사용자가 공유한 주행 기록이나 팀이 등록한 큐레이션 경로에서 만들어진다.
/// 경로·고도·후기 같은 상세 정보는 기본값이 있어서, 목록용으로 제목·거리·시간만 넣어 만들 수도 있다.
struct Course: Identifiable, Hashable {
    let id: String
    /// 카드에 보이는 이름. 보통 도착지 이름(예: "서울한강공원")
    let title: String
    let distanceMeters: Int
    /// 예상 소요 시간. ±20% 오차가 있으니 화면에는 "약 N분"으로만 보여준다.
    let durationSeconds: Int

    var startStationID: Station.ID?
    var endStationID: Station.ID?
    /// 경로 점들(출발 → 도착 순서). 고도가 있으면 경사도 그래프에 쓴다.
    var path: [CoursePoint] = []
    /// 경로 중간의 들를 만한 곳(지도·경사도 그래프의 작은 점)
    var waypoints: [CourseWaypoint] = []
    /// 자전거 전용도로 구간. `path`의 점 인덱스 범위
    var bikeLaneSegments: [ClosedRange<Int>] = []
    var reviews: [CourseReview] = []
    var likeCount = 0
    /// 이 코스로 탄 횟수("탔어요")
    var rideCount = 0
    /// 내가 북마크한 코스인지(저장 코스 탭)
    var isSaved = false
    var createdAt: Date?
    /// 내 주행 기록에서 만든 코스인지(정류장 시트에 "내 기록"으로 표시). 서버 공유 경로가 생기기 전까지 목업 코스와 섞어 보여준다.
    var isMyRide = false

    var coordinates: [CLLocationCoordinate2D] {
        path.map(\.coordinate)
    }

    /// 고도 정보가 없으면 nil
    var maxElevationMeters: Double? {
        path.compactMap(\.elevationMeters).max()
    }

    /// 후기가 없으면 nil
    var averageRating: Double? {
        guard !reviews.isEmpty else { return nil }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }
}

struct CoursePoint: Hashable {
    let latitude: Double
    let longitude: Double
    /// 해발 고도(m). 데이터가 없으면 nil
    var elevationMeters: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct CourseWaypoint: Hashable {
    let name: String
    /// `Course.path`에서의 위치
    let pathIndex: Int
}

struct CourseReview: Identifiable, Hashable {
    let id: String
    /// 1~5
    let rating: Int
    let text: String
    /// 후기 사진(에셋 이름). 없으면 nil
    var photoName: String?
    let createdAt: Date
}

/// 정류장 시트의 코스 탭 (Figma 143:458: 인기 코스 / 최신 코스 / 저장 코스)
enum CourseFilter: CaseIterable, Hashable {
    case popular
    case recent
    case saved

    var title: String {
        switch self {
        case .popular: "인기 코스"
        case .recent: "최신 코스"
        case .saved: "저장 코스"
        }
    }

    /// 1.0에서 보여줄 탭. 인기(다른 사람의 공유 경로)와 저장은 서버 연동(1.1) 후에 다시 넣는다.
    /// 심사에서 "준비 중" 화면은 미완성으로 보고 반려될 수 있어서 아예 숨긴다.
    static let available: [CourseFilter] = [.recent]
}

/// 이용권. 시간권 선택 화면은 아직 디자인이 없어 1시간권을 기본으로 쓴다.
enum TimePass: Hashable {
    case oneHour
    case twoHours

    var duration: TimeInterval {
        switch self {
        case .oneHour: 60 * 60
        case .twoHours: 2 * 60 * 60
        }
    }

    var title: String {
        switch self {
        case .oneHour: "1시간권"
        case .twoHours: "2시간권"
        }
    }
}

enum MainTab: CaseIterable, Hashable {
    case home
    case saved
    case ride
    case profile

    var title: String {
        switch self {
        case .home: "홈"
        case .saved: "저장"
        case .ride: "라이딩"
        case .profile: "MY"
        }
    }

    /// 1.0 탭바에 보여줄 탭. 저장 탭은 디자인과 코스 저장 기능이 나오면 다시 넣는다.
    static let available: [MainTab] = [.home, .ride, .profile]
}
