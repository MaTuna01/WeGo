import Testing
@testable import WeGo

/// 화면 표기 규칙(CLAUDE.md 도메인 규칙: 예상 시간은 "약 N분", 초 단위 금지)
struct WeGoFormatTests {
    @Test func 예상_시간은_약_N분으로_반올림한다() {
        #expect(WeGoFormat.approxMinutes(240) == "약 4분")
        #expect(WeGoFormat.approxMinutes(89) == "약 1분")
        #expect(WeGoFormat.approxMinutes(90) == "약 2분")
    }

    @Test func 예상_시간은_최소_1분이다() {
        #expect(WeGoFormat.approxMinutes(10) == "약 1분")
        #expect(WeGoFormat.approxMinutes(0) == "약 1분")
    }

    @Test func 실제_주행_시간은_약_없이_분과_시간으로_보여준다() {
        #expect(WeGoFormat.minutes(59) == "1분 미만")
        #expect(WeGoFormat.minutes(60) == "1분")
        #expect(WeGoFormat.minutes(119) == "1분")
        #expect(WeGoFormat.minutes(3_600) == "1시간")
        #expect(WeGoFormat.minutes(3_720) == "1시간 2분")
    }

    @Test func 거리는_1km부터_km로_보여준다() {
        #expect(WeGoFormat.distance(850) == "850m")
        #expect(WeGoFormat.distance(999) == "999m")
        #expect(WeGoFormat.distance(1_000) == "1.0km")
        #expect(WeGoFormat.distance(4_321) == "4.3km")
        #expect(WeGoFormat.kilometers(1_234) == "1.2")
        #expect(WeGoFormat.kilometers(-5) == "0.0")
    }

    @Test func 타이머는_시분초와_분초로_보여준다() {
        #expect(WeGoFormat.clock(3_723) == "01:02:03")
        #expect(WeGoFormat.clock(-5) == "00:00:00")
        #expect(WeGoFormat.minutesSeconds(3_725) == "62:05")
        // 시간권 초과는 음수로 들어오고, "초과" 문구는 화면이 붙인다.
        #expect(WeGoFormat.minutesSeconds(-65) == "01:05")
    }
}
