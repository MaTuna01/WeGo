import CoreLocation
import Foundation
import Testing
@testable import WeGo

/// 마이페이지 이용 내역(#56): 시간권 저장, 추가요금 여부, 표기
struct RideHistoryTests {
    private func record(pass: TimePass, rentalMinutes: Double, toWonhyo: Bool = true) -> RideRecord {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = RideSession(startStation: Fixtures.yeouinaru, pass: pass, startedAt: start)
        let end = toWonhyo ? Fixtures.wonhyo.coordinate : Fixtures.yeouinaru.coordinate
        for (index, coordinate) in Fixtures.line(Fixtures.yeouinaru.coordinate, end, steps: 70).enumerated() {
            session.record(Fixtures.location(coordinate, at: start.addingTimeInterval(Double(index)), speed: 5))
        }
        return RideRecord(session: session, endedAt: start.addingTimeInterval(rentalMinutes * 60), stations: Fixtures.stations)
    }

    @Test func 반납하면_주행에서_고른_시간권이_기록에_남는다() {
        #expect(record(pass: .oneHour, rentalMinutes: 30).pass == .oneHour)
        #expect(record(pass: .twoHours, rentalMinutes: 30).pass == .twoHours)
        #expect(record(pass: .twoHours, rentalMinutes: 30).passHours == 2)
    }

    @Test func 대여_시간이_시간권을_넘을_때만_추가요금_발생이다() {
        #expect(!record(pass: .oneHour, rentalMinutes: 60).hasExtraFee)
        #expect(record(pass: .oneHour, rentalMinutes: 61).hasExtraFee)
        #expect(!record(pass: .twoHours, rentalMinutes: 90).hasExtraFee)
        #expect(record(pass: .twoHours, rentalMinutes: 121).hasExtraFee)
    }

    @Test func 시간권_정보가_없던_예전_기록은_1시간권으로_본다() {
        let ride = record(pass: .twoHours, rentalMinutes: 90)
        ride.passHours = 1   // 1.0에서 저장된 기록(기본값)
        #expect(ride.pass == .oneHour)
        #expect(ride.hasExtraFee)
    }

    @Test func 이용_내역_제목은_도착_정류장이고_없으면_출발_정류장_출발이다() {
        #expect(record(pass: .oneHour, rentalMinutes: 10).historyTitle == "여의도 한강공원 원효대교 남단")
        #expect(record(pass: .oneHour, rentalMinutes: 10, toWonhyo: false).historyTitle == "여의나루역 1번출구 앞 출발")
    }

    @Test func 주행_시간은_초까지_보여준다() {
        #expect(WeGoFormat.minutesAndSeconds(42) == "42초")
        #expect(WeGoFormat.minutesAndSeconds(54 * 60 + 42) == "54분 42초")
        #expect(WeGoFormat.minutesAndSeconds(3723) == "1시간 2분 3초")
        #expect(WeGoFormat.minutesAndSeconds(-5) == "0초")
    }

    @Test func 날짜는_월과_일로_나눠_보여준다() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 9))!
        let parts = RideHistoryRow.dateParts(date, calendar: calendar)
        #expect(parts.month == "11월")
        #expect(parts.day == "14일")
    }
}
