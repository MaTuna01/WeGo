import Foundation

// 서버 응답 모델. 계약은 저장소 루트의 docs/api-contract.md를 따른다.
// 서버는 필드를 추가만 하므로 모르는 필드는 무시하고, 모르는 enum 값은 unknown으로 받는다.

/// GET /app/config
struct AppConfigResponse: Decodable, Equatable {
    /// 최소 지원 버전(major.minor.patch). 앱 버전이 이보다 낮으면 업데이트 안내로 막는다.
    let minimumVersion: String
}

/// GET /stations
struct StationsResponse: Decodable {
    let stations: [StationDTO]

    /// 앱에서 쓸 수 있는 정류장만(모르는 운영사, 잘못된 좌표 제외)
    var validStations: [Station] {
        stations.compactMap(\.station)
    }
}

struct StationDTO: Decodable, Equatable {
    let id: String
    let name: String
    let operatorCode: ServerBikeOperator
    let latitude: Double
    let longitude: Double
    let dockCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, dockCount
        case operatorCode = "operator"
    }

    /// 앱 모델로 바꾼다. 모르는 운영사이거나 좌표가 잘못됐으면 nil.
    /// 잔여 대수는 1.0 계약에 없으므로 "정보 없음"(nil)으로 둔다.
    var station: Station? {
        guard let bikeOperator = operatorCode.bikeOperator,
              (-90...90).contains(latitude), (-180...180).contains(longitude),
              !(latitude == 0 && longitude == 0)
        else { return nil }
        return Station(
            id: id, name: name, bikeOperator: bikeOperator,
            latitude: latitude, longitude: longitude,
            dockCount: dockCount ?? 0, availableBikes: nil, updatedAt: nil
        )
    }
}

/// 서버의 운영사 값. 서버가 새 운영사를 추가해도 디코딩이 실패하지 않도록 모르는 값은 unknown으로 받는다.
enum ServerBikeOperator: String, Decodable, Equatable {
    case ttareungyi
    case tashu
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ServerBikeOperator(rawValue: raw) ?? .unknown
    }

    var bikeOperator: BikeOperator? {
        switch self {
        case .ttareungyi: .ttareungyi
        case .tashu: .tashu
        case .unknown: nil
        }
    }
}
