import CoreLocation
import Foundation
import Testing
@testable import WeGo

/// 주행 경로 점 압축 저장(#21)과 고도 추가 전 형식 호환(#25)
struct TrackCodecTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func 압축했다_풀면_경로_점이_그대로다() {
        let points = Fixtures.line(Fixtures.yeouinaru.coordinate, Fixtures.wonhyo.coordinate, steps: 60)
            .enumerated()
            .map { index, coordinate in
                Fixtures.trackPoint(coordinate, at: start.addingTimeInterval(Double(index)), speed: 4.5, altitude: 10 + Double(index) * 0.1)
            }

        let data = TrackCodec.encode(points)
        let decoded = TrackCodec.decode(data)

        #expect(decoded == points)
        #expect(decoded.last?.altitude != nil)
    }

    @Test func 빈_데이터는_빈_경로다() {
        #expect(TrackCodec.decode(Data()).isEmpty)
        #expect(TrackCodec.decode(TrackCodec.encode([])).isEmpty)
    }

    @Test func 깨진_데이터는_빈_경로로_읽는다() {
        #expect(TrackCodec.decode(Data([0x01, 0x02, 0x03])).isEmpty)
    }

    @Test func 고도_추가_전_형식도_고도_없이_읽힌다() throws {
        // 고도를 저장하기 전 앱 버전이 만든 기록과 같은 모양
        struct OldTrackPoint: Codable {
            let latitude: Double
            let longitude: Double
            let timestamp: Date
            let speed: Double?
            let horizontalAccuracy: Double
        }
        let old = [OldTrackPoint(latitude: 37.5271, longitude: 126.9329, timestamp: start, speed: 4.1, horizontalAccuracy: 5)]
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let compressed = try (encoder.encode(old) as NSData).compressed(using: .lzfse) as Data

        let decoded = TrackCodec.decode(compressed)

        #expect(decoded.count == 1)
        #expect(decoded[0].latitude == 37.5271)
        #expect(decoded[0].speed == 4.1)
        #expect(decoded[0].altitude == nil)
    }

    @Test func GPS가_고도를_모르면_고도는_비운다() {
        let point = Fixtures.trackPoint(Fixtures.yeouinaru.coordinate, at: start, altitude: nil)
        #expect(point.altitude == nil)
        #expect(point.speed == nil)
    }
}
