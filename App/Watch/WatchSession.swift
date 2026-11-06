import Foundation
import WatchConnectivity

/// 워치 쪽 연결. iPhone이 보내 준 상태를 보여 주고, "먹었어요"를 iPhone으로 보낸다.
/// iPhone이 멀리 있으면 메시지를 쌓아 뒀다가 다시 연결될 때 보낸다.
final class WatchSession: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSession()

    @Published var state: WatchState?

    private let cacheKey = "kongi.watchState"

    override init() {
        super.init()
        state = loadCache()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func take(_ med: MedSnapshot) {
        let now = Date()

        // 화면에 바로 반영 (iPhone 응답을 기다리지 않는다)
        if var current = state, let index = current.meds.firstIndex(where: { $0.id == med.id }) {
            current.meds[index].recentDoses.append(now)
            current.points += PointRules.dose
            state = current
            saveCache(current)
        }

        let message: [String: Any] = ["take": med.id.uuidString, "at": now]
        let session = WCSession.default
        if session.activationState == .activated && session.isReachable {
            session.sendMessage(message, replyHandler: { [weak self] reply in
                self?.apply(reply)
            }, errorHandler: { _ in
                session.transferUserInfo(message)
            })
        } else {
            session.transferUserInfo(message)
        }
    }

    private func apply(_ dict: [String: Any]) {
        guard let data = dict["state"] as? Data,
              let decoded = try? JSONDecoder().decode(WatchState.self, from: data) else { return }
        DispatchQueue.main.async {
            self.state = decoded
            self.saveCache(decoded)
        }
    }

    private func loadCache() -> WatchState? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(WatchState.self, from: data)
    }

    private func saveCache(_ state: WatchState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if !session.receivedApplicationContext.isEmpty {
            apply(session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }
}
