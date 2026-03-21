import Foundation

@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isVerified = false
    private(set) var userId: String?
    private(set) var email: String?

    // Token lives in Keychain. The rest are non-sensitive metadata in UserDefaults.
    private static let tokenKeychainKey = "quickpod_auth_token"
    private static let userIdKey        = "quickpod_user_id"
    private static let isVerifiedKey    = "quickpod_is_verified"
    private static let emailKey         = "quickpod_email"

    private init() {
        migrateTokenIfNeeded()

        guard let token  = Keychain.load(key: Self.tokenKeychainKey),
              let userId = UserDefaults.standard.string(forKey: Self.userIdKey) else { return }
        self.userId     = userId
        self.email      = UserDefaults.standard.string(forKey: Self.emailKey)
        self.isVerified = UserDefaults.standard.bool(forKey: Self.isVerifiedKey)
        QuickPodAPI.shared.token = token
        isAuthenticated = true
        LibraryStore.shared.switchUser(userId: userId)
    }

    func save(token: String, userId: String, isVerified: Bool, email: String) {
        Keychain.save(token, key: Self.tokenKeychainKey)
        UserDefaults.standard.set(userId,     forKey: Self.userIdKey)
        UserDefaults.standard.set(isVerified, forKey: Self.isVerifiedKey)
        UserDefaults.standard.set(email,      forKey: Self.emailKey)
        QuickPodAPI.shared.token = token
        self.userId     = userId
        self.isVerified = isVerified
        self.email      = email
        isAuthenticated = true
        LibraryStore.shared.switchUser(userId: userId)
    }

    func markVerified() {
        isVerified = true
        UserDefaults.standard.set(true, forKey: Self.isVerifiedKey)
    }

    func signOut() {
        Keychain.delete(key: Self.tokenKeychainKey)
        UserDefaults.standard.removeObject(forKey: Self.userIdKey)
        UserDefaults.standard.removeObject(forKey: Self.isVerifiedKey)
        UserDefaults.standard.removeObject(forKey: Self.emailKey)
        QuickPodAPI.shared.token = nil
        userId      = nil
        email       = nil
        isVerified  = false
        isAuthenticated = false
        LibraryStore.shared.switchUser(userId: nil)
    }

    // MARK: - Migration

    /// Move a token stored in UserDefaults (old behaviour) into the Keychain.
    /// Runs once and is a no-op on every subsequent launch.
    private func migrateTokenIfNeeded() {
        let udKey = Self.tokenKeychainKey
        guard let oldToken = UserDefaults.standard.string(forKey: udKey) else { return }
        Keychain.save(oldToken, key: udKey)
        UserDefaults.standard.removeObject(forKey: udKey)
    }
}
