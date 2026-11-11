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

struct Course: Identifiable, Hashable {
    let id: String
    let title: String
    let distanceMeters: Int
    let durationSeconds: Int
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
        case .profile: "내 정보"
        }
    }
}
