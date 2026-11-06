import Foundation
import UserNotifications

/// 복약 알림. 예정 시각에 한 번, 안 누르면 10분·30분 뒤에 다시 알린다.
/// 마감 시각이 지나면 더 보내지 않는다.
/// iOS는 앱 하나당 예약 알림을 64개까지만 허용하므로 앞으로 3일치만 잡고, 앱을 열거나 기록할 때마다 다시 잡는다.
/// 워치를 차고 있으면 이 알림이 워치로 자동 전달되고, "먹었어요" 버튼도 워치에서 바로 누를 수 있다.
@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    static let categoryID = "DOSE"
    static let takeActionID = "TAKE"

    private let center = UNUserNotificationCenter.current()
    private let prefix = "dose-"
    private let daysAhead = 3
    private let followUpDelays = [0, 10, 30]
    private let maxRequests = 60

    func registerCategories() {
        let take = UNNotificationAction(identifier: Self.takeActionID, title: "먹었어요", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryID, actions: [take], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func reschedule(meds: [MedSnapshot], now: Date = .now) async {
        let pending = await center.pendingNotificationRequests()
        let old = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var requests: [UNNotificationRequest] = []

        outer: for dayOffset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            for med in meds {
                let takenToday = dayOffset == 0 ? med.doses(on: now).count : 0
                for (index, minutes) in med.timesMinutes.sorted().enumerated() {
                    // 오늘 이미 먹은 회차는 건너뛴다
                    if index < takenToday { continue }
                    for (n, delay) in followUpDelays.enumerated() {
                        let total = minutes + delay
                        if let cutoff = med.cutoffMinutes, total >= cutoff { continue }
                        guard let fire = calendar.date(byAdding: .minute, value: total, to: day), fire > now else { continue }

                        let content = UNMutableNotificationContent()
                        content.title = n == 0 ? "약 먹을 시간이에요" : "아직이면 지금 어때요?"
                        content.body = "\(med.name) · 먹었으면 '먹었어요'를 눌러 주세요"
                        content.sound = .default
                        content.categoryIdentifier = Self.categoryID
                        content.threadIdentifier = med.id.uuidString
                        content.userInfo = ["medicationID": med.id.uuidString]

                        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                        let id = "\(prefix)\(med.id.uuidString)-\(dayOffset)-\(minutes)-\(n)"
                        requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                        if requests.count >= maxRequests { break outer }
                    }
                }
            }
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    /// 약을 먹었으면 알림 센터에 남은 그 약 알림을 지운다.
    func clearDelivered(for medicationID: UUID) {
        let key = medicationID.uuidString
        center.getDeliveredNotifications { [center] delivered in
            let ids = delivered
                .filter { ($0.request.content.userInfo["medicationID"] as? String) == key }
                .map(\.request.identifier)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    func notifyAlreadyTaken(name: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "이미 드신 것 같아요"
        content.body = "\(name)은 \(TimeText.hm(date))에 기록돼 있어요. 두 번 드시지 않게 이번 기록은 넣지 않았어요. 앱에서 확인해 주세요."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "already-\(UUID().uuidString)", content: content, trigger: nil)
        center.add(request)
    }
}
