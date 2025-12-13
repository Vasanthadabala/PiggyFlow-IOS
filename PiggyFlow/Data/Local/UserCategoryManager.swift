import SwiftData
import SwiftUI
import Combine

class UserCategoryManager: ObservableObject {
    static let shared = UserCategoryManager()
    
    let container: ModelContainer
    @Published var categories: [UserCategory] = []

    private init() {
        let schema = Schema([UserCategory.self])
        
        // Use a separate store URL for UserCategory
        let storeURL: URL = {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent("UserCategories.store")
        }()

        let config = ModelConfiguration(
            "UserCategories",        // store identifier, acts as unique name
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("❌ Failed to load UserCategory container, deleting old store and retrying: \(error)")
            
            if FileManager.default.fileExists(atPath: storeURL.path) {
                try? FileManager.default.removeItem(at: storeURL)
            }
            
            do {
                container = try ModelContainer(for: schema, configurations: [config])
                print("✅ UserCategory container loaded successfully after reset")
            } catch {
                fatalError("❌ Could not initialize UserCategory container: \(error)")
            }
        }
        
    }
    
    func fetchCategories() {
        do {
            let request = FetchDescriptor<UserCategory>() // optional sorting
            categories = try container.mainContext.fetch(request)
        } catch {
            print("❌ Failed to fetch UserCategories: \(error)")
        }
    }
       
       func addCategory(name: String, emoji: String) {
           let newCategory = UserCategory(name: name, emoji: emoji)
           container.mainContext.insert(newCategory)
           do {
               try container.mainContext.save()
               fetchCategories()
           } catch {
               print("❌ Failed to save new category: \(error)")
           }
       }
}
