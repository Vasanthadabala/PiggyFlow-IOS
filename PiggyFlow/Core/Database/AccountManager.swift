import SwiftData
import SwiftUI
import Combine

/// Local-only store for `Account`, mirroring `UserCategoryManager`'s pattern: its own
/// `ModelContainer` with a named store, kept out of the main synced container and out of
/// `CloudSyncManager` entirely — accounts don't sync across devices yet.
class AccountManager: ObservableObject {
    static let shared = AccountManager()

    let container: ModelContainer
    @Published var accounts: [Account] = []

    private init() {
        let schema = Schema([Account.self])

        let storeURL: URL = {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent("Accounts.store")
        }()

        let config = ModelConfiguration(
            "Accounts",
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("❌ Failed to load Account container, deleting old store and retrying: \(error)")

            if FileManager.default.fileExists(atPath: storeURL.path) {
                try? FileManager.default.removeItem(at: storeURL)
            }

            do {
                container = try ModelContainer(for: schema, configurations: [config])
                print("✅ Account container loaded successfully after reset")
            } catch {
                fatalError("❌ Could not initialize Account container: \(error)")
            }
        }

        // Unlike `UserCategoryManager` (which only populates `categories` the first time
        // `addCategory` runs in a session), fetch immediately — accounts feed dropdown
        // catalogs that need to see previously-saved accounts the moment a screen appears.
        fetchAccounts()
    }

    func fetchAccounts() {
        do {
            accounts = try container.mainContext.fetch(FetchDescriptor<Account>())
        } catch {
            print("❌ Failed to fetch Accounts: \(error)")
        }
    }

    func addAccount(_ account: Account) {
        container.mainContext.insert(account)
        do {
            try container.mainContext.save()
            fetchAccounts()
        } catch {
            print("❌ Failed to save new account: \(error)")
        }
    }

    func deleteAccount(_ account: Account) {
        container.mainContext.delete(account)
        do {
            try container.mainContext.save()
            fetchAccounts()
        } catch {
            print("❌ Failed to delete account: \(error)")
        }
    }
}
