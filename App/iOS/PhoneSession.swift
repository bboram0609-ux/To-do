import Foundation
import WatchConnectivity

/// iPhone ↔ 워치 연결. iPhone이 기록의 주인이고, 워치에는 최신 상태를 보내 준다.
/// 워치에서 "먹었어요"를 누르면 메시지로 받아서 기록한다.
/// iCloud 없이 동작하므로 무료 Apple ID로도 쓸 수 있다.
final class PhoneSession: NSObject, WCSessionDelegate {
    static let shared = PhoneSession()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func push(state: WatchState) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(state) else { return }
        try? session.updateApplicationContext(["state": data])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.push(state: AppModel.shared.watchState())
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // 워치를 바꿔 찼을 때 다시 연결
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.handle(message)
            if let data = try? JSONEncoder().encode(AppModel.shared.watchState()) {
                replyHandler(["state": data])
            } else {
                replyHandler([:])
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handle(userInfo)
        }
    }

    @MainActor
    private func handle(_ message: [String: Any]) {
        guard let raw = message["take"] as? String, let id = UUID(uuidString: raw) else { return }
        let takenAt = (message["at"] as? Date) ?? .now
        // 워치에서 이미 중복 확인을 거쳤으므로 그대로 기록한다.
        AppModel.shared.logDose(medicationID: id, at: takenAt)
    }
}
