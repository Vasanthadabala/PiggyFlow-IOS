import Foundation
import SwiftData

/// SwiftData schema versioning.
///
/// Today `Persistence` recovers from a schema mismatch by *deleting the store* and starting
/// over — acceptable while the app is pre-release and every record also lives in Firestore,
/// but it silently destroys local-only data. Once the app ships, add a new `VersionedSchema`
/// below and a `MigrationStage` linking it to the previous one, then hand
/// `PiggyFlowMigrationPlan.self` to the `ModelContainer` so upgrades preserve data instead.
enum PiggyFlowSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Expense.self, Income.self, TrackerRecord.self]
    }
}

/// Schema for the separate user-category store.
enum UserCategorySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [UserCategory.self]
    }
}

/// Ordered migration path for the main store.
///
/// With a single version there is nothing to migrate yet; `stages` stays empty until a V2
/// is introduced.
enum PiggyFlowMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PiggyFlowSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
