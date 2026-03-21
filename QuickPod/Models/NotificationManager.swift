import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    /// Set when the user taps a push notification; ContentView watches this to navigate.
    @Published var pendingJobId: String?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func registerDeviceToken(_ data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        Task {
            try? await QuickPodAPI.shared.registerDeviceToken(token)
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Show banner + sound even when the app is foregrounded
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }

    // User tapped a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let jobId = userInfo["job_id"] as? String {
            await MainActor.run {
                pendingJobId = jobId
            }
        }
    }
}
