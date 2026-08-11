import SwiftData
import SwiftUI
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    let localContainer: ModelContainer
    
    private init() {
        self.localContainer = Self.createLocalContainer()
    }

    /// Erases everything this device holds: the synced entities, the two satellite stores
    /// (accounts, custom categories), receipt images on disk, and the preferences onboarding
    /// collected. Used by logout and by account deletion so the two can't drift apart.
    ///
    /// Local only — the Firestore backup is deliberately untouched. Logging out shouldn't
    /// destroy the copy the user signs back in to recover; deleting the account is what removes
    /// the cloud data, and `deleteAccount` handles that separately.
    /// - Parameter includingPreferences: `true` (logout, account deletion) also clears the
    ///   onboarding flags and the income/budget/reminder settings, so the app returns to a
    ///   first-run state. `false` (Settings ▸ Clear Local Data) empties the stored records only
    ///   and leaves the user signed in and onboarded, which is what that action promises.
    @MainActor
    func wipeAllLocalData(includingPreferences: Bool = true) {
        // `delete(model:)` is SwiftData's whole-entity wipe: it clears the store directly
        // instead of fetching every row into memory and deleting them one at a time, so it
        // can't leave behind rows a fetch didn't materialise. Each entity is deleted
        // independently so one failure can't abandon the rest half-done.
        let context = localContainer.mainContext
        do {
            try context.delete(model: Expense.self)
            try context.delete(model: Income.self)
            try context.delete(model: TrackerRecord.self)
            try context.save()
        } catch {
            Log.error(error, context: "Wiping local ledger", category: .database)
        }

        let accountContext = AccountManager.shared.container.mainContext
        do {
            try accountContext.delete(model: Account.self)
            try accountContext.save()
        } catch {
            Log.error(error, context: "Wiping accounts", category: .database)
        }
        // Refreshed outside the `do` so the in-memory list is emptied even if the delete threw
        // — otherwise the UI would keep rendering accounts the store no longer has.
        AccountManager.shared.fetchAccounts()

        let categoryContext = UserCategoryManager.shared.container.mainContext
        do {
            try categoryContext.delete(model: UserCategory.self)
            try categoryContext.save()
        } catch {
            Log.error(error, context: "Wiping custom categories", category: .database)
        }
        UserCategoryManager.shared.fetchCategories()

        // Receipt JPEGs live outside SwiftData, so deleting the expenses that referenced them
        // would otherwise leave the files orphaned on disk forever.
        ReceiptStorage.deleteAll()

        guard includingPreferences else { return }

        // Anything onboarding/setup captured, so a fresh sign-in starts genuinely fresh rather
        // than inheriting the previous user's income, budget and reminder choices.
        let defaults = UserDefaults.standard
        [
            AppConstants.Onboarding.completedKey,
            AppConstants.Onboarding.setupStartedKey,
            "monthlyIncome",
            "incomeFrequency",
            "monthlyBudget",
            "reminderWindow",
            "smartNotificationsEnabled",
            AppConstants.UserDefaultsKey.username,
            AppConstants.UserDefaultsKey.userEmail,
            AppConstants.UserDefaultsKey.appleUsername,
            AppConstants.UserDefaultsKey.autoSyncEnabled,
            AppConstants.UserDefaultsKey.firebaseLastSyncDate
        ].forEach { defaults.removeObject(forKey: $0) }
    }
    
    private static func createLocalContainer() -> ModelContainer {
        let schema = Schema([Expense.self, Income.self, TrackerRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("❌ Failed to load local container, deleting old store and retrying: \(error)")
            
            // Delete old store
            let url = config.url
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            
            // Retry
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("❌ Could not initialize local container even after reset: \(error)")
            }
        }
    }
}
