import Foundation

/// App-wide constant values.
///
/// `UserDefaultsKey` in particular exists to kill the scattered string literals that were
/// previously repeated across views — `@AppStorage("username")` appeared in five different
/// files, so a typo in any one of them silently created a second, unrelated setting.
enum AppConstants {

    /// Keys backing `@AppStorage` / `UserDefaults`.
    enum UserDefaultsKey {
        public static let username = "username"
        public static let userEmail = "userEmail"
        public static let appleUsername = "appleUsername"
        /// Must stay in sync with `AppleSignInManager.loginStatusKey`, which is what the
        /// `@AppStorage` bindings in the views actually read.
        public static let isLoggedIn = "isUserLoggedIn"
        public static let autoSyncEnabled = "autoSyncEnabled"
        public static let firebaseLastSyncDate = "firebaseLastSyncDate"
    }

    /// Onboarding runs past sign-in, so "signed in" and "finished onboarding" are separate
    /// states — see `ContentView` for why conflating them broke the flow.
    enum Onboarding {
        public static let completedKey = "hasCompletedOnboarding"
    }

    /// Keychain account identifiers.
    enum KeychainKey {
        public static let appleUserIdentifier = "apple.user.identifier"
    }

    /// SwiftData store names.
    enum Store {
        public static let userCategories = "UserCategories"
    }

    /// Sync behaviour.
    enum Sync {
        /// How long after the last successful sync an auto-sync becomes due.
        public static let autoSyncInterval: TimeInterval = 12 * 60 * 60
    }

    /// Locale/currency used for money formatting throughout the app.
    enum Currency {
        public static let code = "INR"
        public static let symbol = "₹"
        public static let localeIdentifier = "en_IN"
    }
}
