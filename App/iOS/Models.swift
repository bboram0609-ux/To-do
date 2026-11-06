import Foundation
import SwiftData

// 나중에 iCloud 동기화(CloudKit)를 켤 수 있도록 모든 속성에 기본값을 두고 unique 제약은 쓰지 않는다.

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    /// 하루 중 먹는 시각들 (분 단위)
    var timesMinutes: [Int] = []
    /// 늦은 복용 마감 시각 (분 단위). 의사와 정한 값을 사용자가 입력한다.
    var cutoffMinutes: Int?
    /// 남은 약 개수. nil이면 세지 않는다.
    var remainingCount: Int?
    var createdAt: Date = Date()

    init(name: String, timesMinutes: [Int], cutoffMinutes: Int? = nil, remainingCount: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.timesMinutes = timesMinutes.sorted()
        self.cutoffMinutes = cutoffMinutes
        self.remainingCount = remainingCount
        self.createdAt = Date()
    }

    var plannedPerDay: Int { max(timesMinutes.count, 1) }

    func snapshot(logs: [DoseLog], now: Date = .now) -> MedSnapshot {
        let since = now.addingTimeInterval(-48 * 60 * 60)
        let recent = logs.filter { $0.medicationID == id && $0.takenAt >= since }.map(\.takenAt)
        return MedSnapshot(
            id: id,
            name: name,
            timesMinutes: timesMinutes,
            cutoffMinutes: cutoffMinutes,
            recentDoses: recent
        )
    }
}

@Model
final class DoseLog {
    var id: UUID = UUID()
    var medicationID: UUID = UUID()
    var takenAt: Date = Date()

    init(medicationID: UUID, takenAt: Date) {
        self.id = UUID()
        self.medicationID = medicationID
        self.takenAt = takenAt
    }
}

/// 포인트는 쌓이기만 한다. 줄어드는 기록은 만들지 않는다.
@Model
final class PointEvent {
    var id: UUID = UUID()
    var amount: Int = 0
    var reason: String = ""
    var date: Date = Date()

    init(amount: Int, reason: String, date: Date) {
        self.id = UUID()
        self.amount = amount
        self.reason = reason
        self.date = date
    }
}
