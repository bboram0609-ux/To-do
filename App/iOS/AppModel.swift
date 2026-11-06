import Foundation
import SwiftData

/// 데이터 저장소와 "약 먹었어요" 처리를 한곳에 모은다.
/// 화면, 알림 버튼, 워치 어디서 눌러도 이 코드를 거친다.
@MainActor
final class AppModel {
    static let shared = AppModel()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private init() {
        let schema = Schema([Medication.self, DoseLog.self, PointEvent.self])
        do {
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            fatalError("데이터 저장소를 열 수 없어요: \(error)")
        }
    }

    // MARK: - 읽기

    func medications() -> [Medication] {
        (try? context.fetch(FetchDescriptor<Medication>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func medication(id: UUID) -> Medication? {
        let target = id
        var descriptor = FetchDescriptor<Medication>(predicate: #Predicate { $0.id == target })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func recentLogs(now: Date = .now) -> [DoseLog] {
        let since = now.addingTimeInterval(-48 * 60 * 60)
        let descriptor = FetchDescriptor<DoseLog>(predicate: #Predicate { $0.takenAt >= since })
        return (try? context.fetch(descriptor)) ?? []
    }

    func totalPoints() -> Int {
        let events = (try? context.fetch(FetchDescriptor<PointEvent>())) ?? []
        return events.reduce(0) { $0 + $1.amount }
    }

    func lastActivityDate() -> Date? {
        var descriptor = FetchDescriptor<PointEvent>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.date
    }

    func snapshots(now: Date = .now) -> [MedSnapshot] {
        let logs = recentLogs(now: now)
        return medications().map { $0.snapshot(logs: logs, now: now) }
    }

    func watchState(now: Date = .now) -> WatchState {
        WatchState(meds: snapshots(now: now), points: totalPoints(), updatedAt: now)
    }

    // MARK: - 쓰기

    /// 약 먹은 것을 기록한다. 중복 확인은 부르는 쪽(화면, 워치)에서 이미 끝냈다고 본다.
    @discardableResult
    func logDose(medicationID: UUID, at date: Date = .now) -> (points: Int, comeback: Bool)? {
        guard let med = medication(id: medicationID) else { return nil }
        let award = PointRules.award(base: PointRules.dose, lastActivity: lastActivityDate(), now: date)

        context.insert(DoseLog(medicationID: med.id, takenAt: date))
        if let remaining = med.remainingCount {
            med.remainingCount = max(0, remaining - 1)
        }
        let reason = award.comeback ? "\(med.name) · 다시 돌아온 보너스" : "\(med.name) 복용"
        context.insert(PointEvent(amount: award.points, reason: reason, date: date))
        try? context.save()

        ReminderScheduler.shared.clearDelivered(for: med.id)
        Task { await refreshExternal() }
        return award
    }

    /// 알림의 "먹었어요" 버튼처럼 화면 없이 들어온 기록.
    /// 이미 먹은 것 같으면 기록하지 않고 알려 준다 (두 번 먹는 것 방지).
    func handleTakeFromNotification(medicationID: UUID, now: Date = .now) {
        guard let med = medication(id: medicationID) else { return }
        let snap = med.snapshot(logs: recentLogs(now: now), now: now)
        if DoseRules.needsDuplicateConfirm(snap, now: now), let last = snap.lastTaken {
            ReminderScheduler.shared.notifyAlreadyTaken(name: med.name, at: last)
            return
        }
        logDose(medicationID: medicationID, at: now)
    }

    /// 알림 다시 잡기 + 워치에 최신 상태 보내기
    func refreshExternal() async {
        await ReminderScheduler.shared.reschedule(meds: snapshots())
        PhoneSession.shared.push(state: watchState())
    }
}
