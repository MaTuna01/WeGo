import Testing
@testable import WeGo

/// 테스트 타깃이 앱 모듈을 불러오는지 확인하는 첫 테스트. 포맷 테스트는 이 파일에 이어서 늘린다.
struct WeGoFormatTests {
    @Test func 예상_시간은_약_N분으로_반올림한다() {
        #expect(WeGoFormat.approxMinutes(240) == "약 4분")
        #expect(WeGoFormat.approxMinutes(10) == "약 1분")
    }
}
