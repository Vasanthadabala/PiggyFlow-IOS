import Foundation

/// Typed access to `UserDefaults`.
///
/// Views still use `@AppStorage` for values that need to drive SwiftUI updates; this exists
/// for the non-view code (services, sync, use cases) that previously reached for raw
/// `UserDefaults.standard.string(forKey: "username")` with a hand-typed key.
/// Keys live in `AppConstants.UserDefaultsKey` so both paths agree on spelling.
final class UserDefaultsManager {

    static let shared = UserDefaultsManager()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Generic accessors

    func string(_ key: String) -> String? { defaults.string(forKey: key) }
    func bool(_ key: String) -> Bool { defaults.bool(forKey: key) }
    func double(_ key: String) -> Double { defaults.double(forKey: key) }
    func integer(_ key: String) -> Int { defaults.integer(forKey: key) }

    func set(_ value: Any?, for key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func remove(_ key: String) { defaults.removeObject(forKey: key) }

    // MARK: - Codable

    func decode<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func encode<T: Encodable>(_ value: T, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            Log.warning("Failed to encode value for key \(key)", category: .database)
            return
        }
        defaults.set(data, forKey: key)
    }

    // MARK: - Named settings

    var username: String? {
        get { string(AppConstants.UserDefaultsKey.username) }
        set { set(newValue, for: AppConstants.UserDefaultsKey.username) }
    }

    var userEmail: String? {
        get { string(AppConstants.UserDefaultsKey.userEmail) }
        set { set(newValue, for: AppConstants.UserDefaultsKey.userEmail) }
    }

    var isLoggedIn: Bool {
        get { bool(AppConstants.UserDefaultsKey.isLoggedIn) }
        set { set(newValue, for: AppConstants.UserDefaultsKey.isLoggedIn) }
    }

    var autoSyncEnabled: Bool {
        get { bool(AppConstants.UserDefaultsKey.autoSyncEnabled) }
        set { set(newValue, for: AppConstants.UserDefaultsKey.autoSyncEnabled) }
    }

    var lastSyncDate: Date? {
        get {
            let stamp = double(AppConstants.UserDefaultsKey.firebaseLastSyncDate)
            return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
        }
        set {
            set(newValue?.timeIntervalSince1970 ?? 0, for: AppConstants.UserDefaultsKey.firebaseLastSyncDate)
        }
    }

    /// Wipes the user-scoped settings on sign-out / account deletion.
    func clearUserSession() {
        [
            AppConstants.UserDefaultsKey.username,
            AppConstants.UserDefaultsKey.userEmail,
            AppConstants.UserDefaultsKey.appleUsername,
            AppConstants.UserDefaultsKey.isLoggedIn,
            AppConstants.UserDefaultsKey.firebaseLastSyncDate
        ].forEach(remove)
    }
}
