import UserNotifications
import UIKit

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    /// Set when the user taps a push notification; ContentView watches this to navigate.
    @Published var pendingJobId: String?

    /// Last device token received from APNs. Kept so it can be re-sent after login.
    private(set) var deviceToken: String?

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
        deviceToken = token
        sendTokenIfAuthenticated()
    }

    /// Called after login/register so the token is sent even if APNs callback fired first.
    func sendTokenIfAuthenticated() {
        guard let token = deviceToken, QuickPodAPI.shared.token != nil else { return }
        Task {
            try? await QuickPodAPI.shared.registerDeviceToken(token)
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // App is foregrounded — suppress the banner but still handle the job_id so the
    // UI updates even if polling was stopped (e.g. user tapped New mid-job).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if let jobId = notification.request.content.userInfo["job_id"] as? String {
            Task { @MainActor in
                pendingJobId = jobId
            }
        }
        completionHandler([])
    }

    // User tapped a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let jobId = userInfo["job_id"] as? String {
            Task { @MainActor in
                pendingJobId = jobId
            }
        }
        completionHandler()
    }
}
