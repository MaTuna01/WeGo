import Foundation
import os

/// 진행 중 주행을 파일 하나(Application Support/active-ride.plist)에 저장하고 불러온다.
/// 앱이 강제 종료돼도 다시 켜면 이어서 기록하려는 용도다. 반납하면 지운다.
/// 쓰기는 별도 큐에서 하고, 마지막 저장 시각으로 너무 자주 쓰지 않게 한다.
final class ActiveRideStore {
    /// 주행 중 위치가 들어올 때는 이 간격마다만 저장한다(초).
    static let throttleInterval: TimeInterval = 10

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.matuna01.wego.active-ride", qos: .utility)
    private let logger = Logger(subsystem: "com.matuna01.wego", category: "ActiveRide")
    private var lastSavedAt: Date?

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("active-ride.plist")
    }

    /// 바로 저장한다(시작·일시정지·코스 취소·백그라운드 진입 때).
    func save(_ session: RideSession) {
        write(session.snapshot)
    }

    /// 마지막 저장 후 일정 시간이 지났을 때만 저장한다(위치가 들어올 때마다 부른다).
    func saveIfNeeded(_ session: RideSession, now: Date = .now) {
        if let lastSavedAt, now.timeIntervalSince(lastSavedAt) < Self.throttleInterval { return }
        write(session.snapshot)
    }

    func load() -> RideSession.Snapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try PropertyListDecoder().decode(RideSession.Snapshot.self, from: data)
        } catch {
            logger.error("진행 중 주행 불러오기 실패, 버림: \(error.localizedDescription, privacy: .public)")
            clear()
            return nil
        }
    }

    func clear() {
        lastSavedAt = nil
        let url = fileURL
        queue.async { try? FileManager.default.removeItem(at: url) }
    }

    private func write(_ snapshot: RideSession.Snapshot) {
        lastSavedAt = .now
        let url = fileURL
        let logger = logger
        queue.async {
            do {
                let encoder = PropertyListEncoder()
                encoder.outputFormat = .binary
                try encoder.encode(snapshot).write(to: url, options: .atomic)
                logger.debug("진행 중 주행 저장: \(snapshot.trackPoints.count, privacy: .public)점")
            } catch {
                logger.error("진행 중 주행 저장 실패: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
