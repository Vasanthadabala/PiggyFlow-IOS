import Foundation
import SwiftData

/// Composition root — the one place that knows how the app's services are built and wired.
///
/// Dependencies are currently reached through global singletons (`DataManager.shared`,
/// `CloudSyncManager.shared`, …). That works, but it hardcodes the concrete type at every
/// call site, so a test can't substitute a fake. Resolving through the container instead
/// keeps construction in one place and makes those seams available.
@MainActor
final class AppContainer {

    static let shared = AppContainer()

    // MARK: - Infrastructure

    let persistence: DataManager
    let categories: UserCategoryManager
    let cloudSync: CloudSyncManager
    let apiClient: APIClientProtocol
    let userDefaults: UserDefaultsManager
    let keychain: KeychainManager
    let files: FileStorageManager

    // MARK: - Child containers

    private(set) lazy var repositories = RepositoryContainer(container: self)
    private(set) lazy var useCases = UseCaseContainer(repositories: repositories)

    private init(
        persistence: DataManager = .shared,
        categories: UserCategoryManager = .shared,
        cloudSync: CloudSyncManager = .shared,
        apiClient: APIClientProtocol = APIClient(),
        userDefaults: UserDefaultsManager = .shared,
        keychain: KeychainManager = .shared,
        files: FileStorageManager = .shared
    ) {
        self.persistence = persistence
        self.categories = categories
        self.cloudSync = cloudSync
        self.apiClient = apiClient
        self.userDefaults = userDefaults
        self.keychain = keychain
        self.files = files
    }

    /// The container backing the main SwiftData store.
    var modelContainer: ModelContainer { persistence.localContainer }
}
