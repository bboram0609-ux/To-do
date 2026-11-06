import SwiftUI
import SwiftData
import UserNotifications

@main
struct KongiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppModel.shared.container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in
            ReminderScheduler.shared.registerCategories()
        }
        PhoneSession.shared.activate()
        return true
    }

    // 앱을 보고 있을 때도 알림을 띄운다
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    // 알림의 "먹었어요" 버튼 (iPhone, 워치 모두 여기로 온다)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == ReminderScheduler.takeActionID,
              let raw = response.notification.request.content.userInfo["medicationID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run {
            AppModel.shared.handleTakeFromNotification(medicationID: id)
        }
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("오늘", systemImage: "sun.max") }
            GardenView()
                .tabItem { Label("나의 정원", systemImage: "leaf") }
            SettingsView()
                .tabItem { Label("기록·설정", systemImage: "gearshape") }
        }
        .tint(KongiColors.accent)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await AppModel.shared.refreshExternal() }
            }
        }
    }
}
