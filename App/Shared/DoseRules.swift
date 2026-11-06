import Foundation

/// iPhone과 워치가 함께 쓰는 약 한 개의 상태.
struct MedSnapshot: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    /// 하루 중 먹는 시각들 (자정부터 분 단위, 예: 8:30 → 510)
    var timesMinutes: [Int]
    /// 이 시각 이후로는 알림을 보내지 않는다 (분 단위). nil이면 마감 없음.
    var cutoffMinutes: Int?
    /// 최근 48시간 동안 먹은 시각들
    var recentDoses: [Date]

    var plannedPerDay: Int { max(timesMinutes.count, 1) }
    var lastTaken: Date? { recentDoses.max() }

    func doses(on day: Date, calendar: Calendar = .current) -> [Date] {
        recentDoses.filter { calendar.isDate($0, inSameDayAs: day) }.sorted()
    }

    func isDone(on day: Date, calendar: Calendar = .current) -> Bool {
        doses(on: day, calendar: calendar).count >= plannedPerDay
    }

    /// 오늘 아직 안 먹은 다음 예정 시각 (분 단위)
    func nextPlannedMinutes(on day: Date, calendar: Calendar = .current) -> Int? {
        let taken = doses(on: day, calendar: calendar).count
        let sorted = timesMinutes.sorted()
        return taken < sorted.count ? sorted[taken] : nil
    }
}

/// 워치로 보내는 전체 상태
struct WatchState: Codable, Equatable {
    var meds: [MedSnapshot]
    var points: Int
    var updatedAt: Date
}

enum DoseRules {
    /// 이 시간 안에 같은 약을 또 누르면 한 번 더 확인한다.
    static let duplicateWindow: TimeInterval = 2 * 60 * 60
    /// 남은 약이 이 일수 이하이면 처방 받을 때라고 알린다.
    static let refillWarningDays = 7

    /// 두 번 먹는 것을 막기 위해 한 번 더 물어봐야 하는지
    static func needsDuplicateConfirm(_ med: MedSnapshot, now: Date, calendar: Calendar = .current) -> Bool {
        if med.isDone(on: now, calendar: calendar) { return true }
        if let last = med.lastTaken, now.timeIntervalSince(last) < duplicateWindow { return true }
        return false
    }

    static func isPastCutoff(_ med: MedSnapshot, now: Date, calendar: Calendar = .current) -> Bool {
        guard let cutoff = med.cutoffMinutes else { return false }
        return minutesOfDay(now, calendar: calendar) >= cutoff
    }

    static func daysLeft(remainingCount: Int?, plannedPerDay: Int) -> Int? {
        guard let remaining = remainingCount else { return nil }
        return remaining / max(plannedPerDay, 1)
    }

    static func minutesOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

enum PointRules {
    static let dose = 10
    /// 이만큼 쉬었다가 돌아오면 포인트 두 배
    static let comebackGap: TimeInterval = 3 * 24 * 60 * 60

    static func award(base: Int, lastActivity: Date?, now: Date) -> (points: Int, comeback: Bool) {
        guard let last = lastActivity, now.timeIntervalSince(last) >= comebackGap else {
            return (base, false)
        }
        return (base * 2, true)
    }
}

enum TimeText {
    /// "오전 8:12" 같은 짧은 시각
    static func hm(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func label(minutes: Int, calendar: Calendar = .current) -> String {
        let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        return hm(date)
    }
}
