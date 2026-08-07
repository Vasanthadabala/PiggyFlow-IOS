import Foundation
import SwiftData

/// Builds the Data-layer repositories.
///
/// Repositories need a `ModelContext`, and the right context depends on the caller — SwiftUI
/// views get one injected through the environment, background work needs its own. So these
/// are factory methods taking a context rather than stored singletons; caching one would
/// pin every caller to whichever context happened to create it first.
@MainActor
final class RepositoryContainer {

    private unowned let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    /// Expenses and income, backed by SwiftData and wired for cloud sync.
    func expenseRepository(context: ModelContext) -> ExpenseRepository {
        ExpenseRepositoryImpl(context: context, cloudSync: container.cloudSync)
    }

    /// Authentication, wrapping the app-level sign-in manager.
    func authRepository(manager: AppleSignInManager) -> AuthRepository {
        AuthRepositoryImpl(manager: manager, userDefaults: container.userDefaults)
    }
}
