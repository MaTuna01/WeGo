import Foundation

enum WeGoFormat {
    /// 01:02:03
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// 62:05 (분:초, 시간권 남은 시간 표시용)
    static func minutesSeconds(_ interval: TimeInterval) -> String {
        let total = max(0, Int(abs(interval)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// 1.2 (km 단위 숫자만)
    static func kilometers(_ meters: Double) -> String {
        String(format: "%.1f", max(0, meters) / 1000)
    }

    /// 4.3km / 850m
    static func distance(_ meters: Int) -> String {
        meters >= 1000 ? String(format: "%.1fkm", Double(meters) / 1000) : "\(meters)m"
    }

    /// 예상 시간은 ±20% 오차가 있어 "약 N분"으로만 표시한다.
    static func approxMinutes(_ seconds: Int) -> String {
        "약 \(max(1, Int((Double(seconds) / 60).rounded())))분"
    }

    static func won(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}
