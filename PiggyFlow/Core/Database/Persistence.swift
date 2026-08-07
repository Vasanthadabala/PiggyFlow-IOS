import SwiftData
import SwiftUI
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    let localContainer: ModelContainer
    
    private init() {
        self.localContainer = Self.createLocalContainer()
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
