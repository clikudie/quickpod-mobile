import Foundation

@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    @Published private(set) var isAuthenticated = false
    private(set) var userId: String?

    private static let tokenKey = "quickpod_auth_token"
    private static let userIdKey = "quickpod_user_id"

    private init() {
        if let token = UserDefaults.standard.string(forKey: Self.tokenKey),
           let userId = UserDefaults.standard.string(forKey: Self.userIdKey) {
            self.userId = userId
            QuickPodAPI.shared.token = token
            isAuthenticated = true
            LibraryStore.shared.switchUser(userId: userId)
        }
    }

    func save(token: String, userId: String) {
        UserDefaults.standard.set(token, forKey: Self.tokenKey)
        UserDefaults.standard.set(userId, forKey: Self.userIdKey)
        QuickPodAPI.shared.token = token
        self.userId = userId
        isAuthenticated = true
        LibraryStore.shared.switchUser(userId: userId)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: Self.tokenKey)
        UserDefaults.standard.removeObject(forKey: Self.userIdKey)
        QuickPodAPI.shared.token = nil
        userId = nil
        isAuthenticated = false
        LibraryStore.shared.switchUser(userId: nil)
    }
}
