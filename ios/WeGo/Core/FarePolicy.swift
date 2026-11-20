import Foundation

/// 운영사별 요금 정책. 정책값은 추후 서버에서 내려받도록 교체한다.
protocol FarePolicy {
    /// 시간권 초과 추가요금(원). 기본 이용권 요금은 결제 시점에 이미 냈으므로 포함하지 않는다.
    func overtimeFee(rentalElapsed: TimeInterval, pass: TimePass) -> Int
}

/// 따릉이: 시간권 초과 시 5분마다 200원 (정책값 확인 필요)
struct TtareungyiFarePolicy: FarePolicy {
    var unit: TimeInterval = 5 * 60
    var feePerUnit = 200

    func overtimeFee(rentalElapsed: TimeInterval, pass: TimePass) -> Int {
        let over = rentalElapsed - pass.duration
        guard over > 0 else { return 0 }
        return Int((over / unit).rounded(.up)) * feePerUnit
    }
}
