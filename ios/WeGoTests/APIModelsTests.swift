import Foundation
import Testing
@testable import WeGo

/// 서버 응답 디코딩(docs/api-contract.md). 서버가 필드나 enum 값을 추가해도 구버전 앱이 깨지지 않아야 한다.
struct APIModelsTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test func 앱_설정을_읽는다() throws {
        let config = try decode(AppConfigResponse.self, #"{"minimumVersion": "1.0.0"}"#)
        #expect(config.minimumVersion == "1.0.0")
    }

    @Test func 모르는_필드가_추가돼도_읽는다() throws {
        let config = try decode(AppConfigResponse.self, #"{"minimumVersion": "1.2.0", "latestVersion": "1.3.0", "notice": {"title": "점검"}}"#)
        #expect(config.minimumVersion == "1.2.0")

        let stations = try decode(StationsResponse.self, """
        {"stations": [{"id": "ST-1", "name": "정류장", "operator": "ttareungyi",
                       "latitude": 37.5, "longitude": 126.9, "dockCount": 10,
                       "availableBikes": 3, "address": "서울"}],
         "generatedAt": "2026-11-19T00:00:00Z"}
        """)
        #expect(stations.validStations.count == 1)
    }

    @Test func 정류장을_앱_모델로_바꾸고_잔여_대수는_정보_없음으로_둔다() throws {
        let response = try decode(StationsResponse.self, """
        {"stations": [{"id": "ST-1", "name": "여의나루역 1번출구 앞", "operator": "ttareungyi",
                       "latitude": 37.5271, "longitude": 126.9329, "dockCount": 15},
                      {"id": "TS-1", "name": "엑스포다리 남단", "operator": "tashu",
                       "latitude": 36.3763, "longitude": 127.3872, "dockCount": 8}]}
        """)
        let stations = response.validStations

        #expect(stations.map(\.id) == ["ST-1", "TS-1"])
        #expect(stations.map(\.bikeOperator) == [.ttareungyi, .tashu])
        #expect(stations[0].name == "여의나루역 1번출구 앞")
        #expect(stations[0].latitude == 37.5271)
        #expect(stations[0].dockCount == 15)
        #expect(stations[0].availableBikes == nil)
        #expect(stations[0].updatedAt == nil)
    }

    @Test func 모르는_운영사는_unknown으로_받고_목록에서_뺀다() throws {
        let response = try decode(StationsResponse.self, """
        {"stations": [{"id": "X-1", "name": "새 운영사 정류장", "operator": "eoulling",
                       "latitude": 35.1, "longitude": 129.0, "dockCount": 5},
                      {"id": "ST-1", "name": "정류장", "operator": "ttareungyi",
                       "latitude": 37.5, "longitude": 126.9, "dockCount": 10}]}
        """)

        #expect(response.stations[0].operatorCode == .unknown)
        #expect(response.validStations.map(\.id) == ["ST-1"])
    }

    @Test func 거치대_수가_없거나_null이면_0으로_둔다() throws {
        let response = try decode(StationsResponse.self, """
        {"stations": [{"id": "A", "name": "a", "operator": "ttareungyi", "latitude": 37.5, "longitude": 126.9},
                      {"id": "B", "name": "b", "operator": "ttareungyi", "latitude": 37.5, "longitude": 126.9, "dockCount": null}]}
        """)
        #expect(response.validStations.map(\.dockCount) == [0, 0])
    }

    @Test func 잘못된_좌표의_정류장은_버린다() throws {
        let response = try decode(StationsResponse.self, """
        {"stations": [{"id": "ZERO", "name": "z", "operator": "ttareungyi", "latitude": 0, "longitude": 0},
                      {"id": "LAT", "name": "l", "operator": "ttareungyi", "latitude": 91, "longitude": 126.9},
                      {"id": "LON", "name": "o", "operator": "ttareungyi", "latitude": 37.5, "longitude": 181},
                      {"id": "OK", "name": "k", "operator": "ttareungyi", "latitude": 37.5, "longitude": 126.9}]}
        """)
        #expect(response.validStations.map(\.id) == ["OK"])
    }

    @Test func 필수_필드가_빠지면_디코딩에_실패한다() {
        #expect(throws: DecodingError.self) {
            try decode(StationsResponse.self, #"{"stations": [{"id": "A", "operator": "ttareungyi", "latitude": 37.5, "longitude": 126.9}]}"#)
        }
        #expect(throws: DecodingError.self) {
            try decode(AppConfigResponse.self, "{}")
        }
    }
}
