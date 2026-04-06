import Foundation
import SwiftData
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    @Published private(set) var isRestoringFromCloud = false

    private enum EntityKind: String, CaseIterable {
        case expense = "expenses"
        case income = "incomes"
        case tracker = "trackers"
    }

    private enum OperationType {
        case upsert(data: [String: Any], timestamp: Date)
        case delete
    }

    private struct PendingOperation {
        let kind: EntityKind
        let id: String
        let operation: OperationType
    }

    private var pendingOperations: [String: PendingOperation] = [:]
    private var debounceTask: Task<Void, Never>?
    private var isFlushing = false
    private var isBootstrapping = false
    private var bootstrappedUID: String?
    private var modelContext: ModelContext?

#if canImport(FirebaseFirestore)
    private var listeners: [ListenerRegistration] = []
    private let firestore = Firestore.firestore()
#endif

    private init() {}

    func handleLoginIfNeeded(context: ModelContext) {
        modelContext = context
#if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Task {
            await bootstrapSyncIfNeeded(uid: uid, context: context)
            startRealtimeListenersIfNeeded(uid: uid, context: context)
        }
#endif
    }

    func handleLogout() {
        pendingOperations.removeAll()
        debounceTask?.cancel()
        debounceTask = nil
        isFlushing = false
        isBootstrapping = false
        isRestoringFromCloud = false
        bootstrappedUID = nil
        modelContext = nil
        stopRealtimeListeners()
    }

    func syncNow(context: ModelContext? = nil) async -> Bool {
#if canImport(FirebaseAuth)
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let activeContext = context ?? modelContext
        guard let activeContext else { return false }
        modelContext = activeContext

        await flushPendingOperations()
        await pushAllLocalData(uid: uid, context: activeContext)
        await pullAllRemoteData(uid: uid, context: activeContext)
        bootstrappedUID = uid
        return true
#else
        return false
#endif
    }

    func queueExpenseUpsert(_ expense: Expense) {
        let now = Date()
        markDirty(kind: .expense, id: expense.id, at: now)
        upsert(
            kind: .expense,
            id: expense.id,
            data: [
                "id": expense.id,
                "type": expense.type,
                "emoji": expense.emoji,
                "name": expense.name,
                "price": expense.price,
                "date": timestamp(from: expense.date),
                "note": expense.note,
                "updatedAt": timestamp(from: now)
            ],
            timestamp: now
        )
    }

    func queueIncomeUpsert(_ income: Income) {
        let now = Date()
        markDirty(kind: .income, id: income.id, at: now)
        upsert(
            kind: .income,
            id: income.id,
            data: [
                "id": income.id,
                "type": income.type,
                "emoji": income.emoji,
                "name": income.name,
                "income": income.income,
                "date": timestamp(from: income.date),
                "note": income.note,
                "updatedAt": timestamp(from: now)
            ],
            timestamp: now
        )
    }

    func queueTrackerUpsert(_ tracker: TrackerRecord) {
        let now = Date()
        markDirty(kind: .tracker, id: tracker.id, at: now)
        upsert(
            kind: .tracker,
            id: tracker.id,
            data: [
                "id": tracker.id,
                "type": tracker.type,
                "name": tracker.name,
                "subType": tracker.subType,
                "amount": tracker.amount,
                "dueDate": timestamp(from: tracker.dueDate),
                "logoUrl": tracker.logoUrl,
                "updatedAt": timestamp(from: now)
            ],
            timestamp: now
        )
    }

    func queueDeleteExpense(id: String) {
        queueDelete(kind: .expense, id: id)
    }

    func queueDeleteIncome(id: String) {
        queueDelete(kind: .income, id: id)
    }

    func queueDeleteTracker(id: String) {
        queueDelete(kind: .tracker, id: id)
    }

    private func upsert(kind: EntityKind, id: String, data: [String: Any], timestamp: Date) {
        let key = operationKey(kind: kind, id: id)
        pendingOperations[key] = PendingOperation(
            kind: kind,
            id: id,
            operation: .upsert(data: data, timestamp: timestamp)
        )
        scheduleFlush()
    }

    private func queueDelete(kind: EntityKind, id: String) {
        clearDirty(kind: kind, id: id)
        let key = operationKey(kind: kind, id: id)
        pendingOperations[key] = PendingOperation(kind: kind, id: id, operation: .delete)
        scheduleFlush()
    }

    private func operationKey(kind: EntityKind, id: String) -> String {
        "\(kind.rawValue)_\(id)"
    }

    private func scheduleFlush() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await self?.flushPendingOperations()
        }
    }

    private func flushPendingOperations() async {
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if isFlushing { return }
        guard !pendingOperations.isEmpty else { return }

        isFlushing = true
        let operations = Array(pendingOperations.values)
        pendingOperations.removeAll()

        for op in operations {
            do {
                let ref = firestore.collection(userCollectionPath(uid: uid, kind: op.kind)).document(op.id)
                switch op.operation {
                case .upsert(let data, let timestamp):
                    try await ref.setData(data, merge: true)
                    if let dirtyAt = dirtyDate(kind: op.kind, id: op.id), dirtyAt <= timestamp {
                        clearDirty(kind: op.kind, id: op.id)
                    }
                case .delete:
                    try await ref.delete()
                }
            } catch {
                let key = operationKey(kind: op.kind, id: op.id)
                pendingOperations[key] = op
                print("⚠️ Firebase sync failed for \(op.kind.rawValue)/\(op.id): \(error.localizedDescription)")
            }
        }

        isFlushing = false
        if !pendingOperations.isEmpty {
            scheduleFlush()
        }
#endif
    }

    private func bootstrapSyncIfNeeded(uid: String, context: ModelContext) async {
        if isBootstrapping { return }
        isBootstrapping = true

        let restoredFromBackup = await pullAllRemoteData(uid: uid, context: context)
        await flushPendingOperations()
        if !restoredFromBackup {
            // No cloud backup yet, so seed Firebase from local store.
            await pushAllLocalData(uid: uid, context: context)
        } else {
            // Backup restored; still push to upload any local-only dirty changes.
            await pushAllLocalData(uid: uid, context: context)
        }

        bootstrappedUID = uid
        isBootstrapping = false
    }

    private func pushAllLocalData(uid: String, context: ModelContext) async {
#if canImport(FirebaseFirestore)
        do {
            let expenses = try context.fetch(FetchDescriptor<Expense>())
            for expense in expenses {
                let dirtyAt = dirtyDate(kind: .expense, id: expense.id) ?? Date()
                let data: [String: Any] = [
                    "id": expense.id,
                    "type": expense.type,
                    "emoji": expense.emoji,
                    "name": expense.name,
                    "price": expense.price,
                    "date": timestamp(from: expense.date),
                    "note": expense.note,
                    "updatedAt": timestamp(from: dirtyAt)
                ]
                try await firestore
                    .collection(userCollectionPath(uid: uid, kind: .expense))
                    .document(expense.id)
                    .setData(data, merge: true)
                clearDirty(kind: .expense, id: expense.id)
            }

            let incomes = try context.fetch(FetchDescriptor<Income>())
            for income in incomes {
                let dirtyAt = dirtyDate(kind: .income, id: income.id) ?? Date()
                let data: [String: Any] = [
                    "id": income.id,
                    "type": income.type,
                    "emoji": income.emoji,
                    "name": income.name,
                    "income": income.income,
                    "date": timestamp(from: income.date),
                    "note": income.note,
                    "updatedAt": timestamp(from: dirtyAt)
                ]
                try await firestore
                    .collection(userCollectionPath(uid: uid, kind: .income))
                    .document(income.id)
                    .setData(data, merge: true)
                clearDirty(kind: .income, id: income.id)
            }

            let trackers = try context.fetch(FetchDescriptor<TrackerRecord>())
            for tracker in trackers {
                let dirtyAt = dirtyDate(kind: .tracker, id: tracker.id) ?? Date()
                let data: [String: Any] = [
                    "id": tracker.id,
                    "type": tracker.type,
                    "name": tracker.name,
                    "subType": tracker.subType,
                    "amount": tracker.amount,
                    "dueDate": timestamp(from: tracker.dueDate),
                    "logoUrl": tracker.logoUrl,
                    "updatedAt": timestamp(from: dirtyAt)
                ]
                try await firestore
                    .collection(userCollectionPath(uid: uid, kind: .tracker))
                    .document(tracker.id)
                    .setData(data, merge: true)
                clearDirty(kind: .tracker, id: tracker.id)
            }
        } catch {
            print("❌ Bootstrap upload failed: \(error.localizedDescription)")
        }
#endif
    }

    private func pullAllRemoteData(uid: String, context: ModelContext) async -> Bool {
#if canImport(FirebaseFirestore)
        isRestoringFromCloud = true
        defer { isRestoringFromCloud = false }
        do {
            let expenseSnapshot = try await firestore
                .collection(userCollectionPath(uid: uid, kind: .expense))
                .getDocuments()

            let incomeSnapshot = try await firestore
                .collection(userCollectionPath(uid: uid, kind: .income))
                .getDocuments()

            let trackerSnapshot = try await firestore
                .collection(userCollectionPath(uid: uid, kind: .tracker))
                .getDocuments()

            let hasBackup = (expenseSnapshot.documents.count + incomeSnapshot.documents.count + trackerSnapshot.documents.count) > 0

            if hasBackup {
                applyExpenseFullSnapshot(expenseSnapshot, context: context)
                applyIncomeFullSnapshot(incomeSnapshot, context: context)
                applyTrackerFullSnapshot(trackerSnapshot, context: context)
            }

            return hasBackup
        } catch {
            print("❌ Bootstrap download failed: \(error.localizedDescription)")
            return false
        }
#else
        return false
#endif
    }

#if canImport(FirebaseFirestore)
    private func startRealtimeListenersIfNeeded(uid: String, context: ModelContext) {
        guard listeners.isEmpty else { return }

        let expenseListener = firestore
            .collection(userCollectionPath(uid: uid, kind: .expense))
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.applyExpenseSnapshot(snapshot, context: context)
                }
            }

        let incomeListener = firestore
            .collection(userCollectionPath(uid: uid, kind: .income))
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.applyIncomeSnapshot(snapshot, context: context)
                }
            }

        let trackerListener = firestore
            .collection(userCollectionPath(uid: uid, kind: .tracker))
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.applyTrackerSnapshot(snapshot, context: context)
                }
            }

        listeners = [expenseListener, incomeListener, trackerListener]
    }

    private func stopRealtimeListeners() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
#else
    private func stopRealtimeListeners() {}
#endif

    private func userCollectionPath(uid: String, kind: EntityKind) -> String {
        "users/\(uid)/\(kind.rawValue)"
    }

    private func dirtyStoreKey(for kind: EntityKind) -> String {
        "firebase_sync_dirty_\(kind.rawValue)"
    }

    private func markDirty(kind: EntityKind, id: String, at date: Date) {
        var map = dirtyMap(kind: kind)
        map[id] = date.timeIntervalSince1970
        UserDefaults.standard.set(map, forKey: dirtyStoreKey(for: kind))
    }

    private func dirtyDate(kind: EntityKind, id: String) -> Date? {
        let map = dirtyMap(kind: kind)
        guard let value = map[id] else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    private func clearDirty(kind: EntityKind, id: String) {
        var map = dirtyMap(kind: kind)
        map.removeValue(forKey: id)
        UserDefaults.standard.set(map, forKey: dirtyStoreKey(for: kind))
    }

    private func dirtyMap(kind: EntityKind) -> [String: Double] {
        UserDefaults.standard.dictionary(forKey: dirtyStoreKey(for: kind)) as? [String: Double] ?? [:]
    }

#if canImport(FirebaseFirestore)
    private func applyExpenseSnapshot(_ snapshot: QuerySnapshot, context: ModelContext) {
        do {
            let locals = try context.fetch(FetchDescriptor<Expense>())
            var map = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })
            var changed = false

            for change in snapshot.documentChanges {
                let id = change.document.documentID
                switch change.type {
                case .removed:
                    if dirtyDate(kind: .expense, id: id) == nil, let local = map[id] {
                        context.delete(local)
                        map.removeValue(forKey: id)
                        changed = true
                    }
                case .added, .modified:
                    let data = change.document.data()
                    let remoteUpdatedAt = dateValue(from: data["updatedAt"])
                    if let dirtyAt = dirtyDate(kind: .expense, id: id), dirtyAt > remoteUpdatedAt {
                        if let local = map[id] {
                            queueExpenseUpsert(local)
                        }
                        continue
                    }

                    let expense = map[id] ?? {
                        let created = Expense(type: "Expense")
                        created.id = id
                        context.insert(created)
                        map[id] = created
                        changed = true
                        return created
                    }()

                    expense.type = stringValue(from: data["type"])
                    expense.emoji = stringValue(from: data["emoji"])
                    expense.name = stringValue(from: data["name"])
                    expense.price = doubleValue(from: data["price"])
                    expense.date = dateValue(from: data["date"])
                    expense.note = stringValue(from: data["note"])
                    clearDirty(kind: .expense, id: id)
                    changed = true
                }
            }

            if changed {
                try context.save()
            }
        } catch {
            print("❌ Applying expense snapshot failed: \(error.localizedDescription)")
        }
    }

    private func applyExpenseFullSnapshot(_ snapshot: QuerySnapshot, context: ModelContext) {
        do {
            let locals = try context.fetch(FetchDescriptor<Expense>())
            var map = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })
            var changed = false

            for doc in snapshot.documents {
                let id = doc.documentID
                let data = doc.data()
                let remoteUpdatedAt = dateValue(from: data["updatedAt"])

                if let dirtyAt = dirtyDate(kind: .expense, id: id), dirtyAt > remoteUpdatedAt {
                    if let local = map[id] {
                        queueExpenseUpsert(local)
                    }
                    continue
                }

                let expense = map[id] ?? {
                    let created = Expense(type: "Expense")
                    created.id = id
                    context.insert(created)
                    map[id] = created
                    changed = true
                    return created
                }()

                expense.type = stringValue(from: data["type"])
                expense.emoji = stringValue(from: data["emoji"])
                expense.name = stringValue(from: data["name"])
                expense.price = doubleValue(from: data["price"])
                expense.date = dateValue(from: data["date"])
                expense.note = stringValue(from: data["note"])
                clearDirty(kind: .expense, id: id)
                changed = true
            }

            if changed {
                try context.save()
            }
        } catch {
            print("❌ Applying full expense snapshot failed: \(error.localizedDescription)")
        }
    }

    private func applyIncomeSnapshot(_ snapshot: QuerySnapshot, context: ModelContext) {
        do {
            let locals = try context.fetch(FetchDescriptor<Income>())
            var map = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })
            var changed = false

            for change in snapshot.documentChanges {
                let id = change.document.documentID
                switch change.type {
                case .removed:
                    if dirtyDate(kind: .income, id: id) == nil, let local = map[id] {
                        context.delete(local)
                        map.removeValue(forKey: id)
                        changed = true
                    }
                case .added, .modified:
                    let data = change.document.data()
                    let remoteUpdatedAt = dateValue(from: data["updatedAt"])
                    if let dirtyAt = dirtyDate(kind: .income, id: id), dirtyAt > remoteUpdatedAt {
                        if let local = map[id] {
                            queueIncomeUpsert(local)
                        }
                        continue
                    }

                    let income = map[id] ?? {
                        let created = Income(type: "Income")
                        created.id = id
                        context.insert(created)
                        map[id] = created
                        changed = true
                        return created
                    }()

                    income.type = stringValue(from: data["type"])
                    income.emoji = stringValue(from: data["emoji"])
                    income.name = stringValue(from: data["name"])
                    income.income = doubleValue(from: data["income"])
                    income.date = dateValue(from: data["date"])
                    income.note = stringValue(from: data["note"])
                    clearDirty(kind: .income, id: id)
                    changed = true
                }
            }

            if changed {
                try context.save()
            }
        } catch {
            print("❌ Applying income snapshot failed: \(error.localizedDescription)")
        }
    }

    private func applyIncomeFullSnapshot(_ snapshot: QuerySnapshot, context: ModelContext) {
        do {
            let locals = try context.fetch(FetchDescriptor<Income>())
            var map = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })
            var changed = false

            for doc in snapshot.documents {
                let id = doc.documentID
                let data = doc.data()
                let remoteUpdatedAt = dateValue(from: data["updatedAt"])

                if let dirtyAt = dirtyDate(kind: .income, id: id), dirtyAt > remoteUpdatedAt {
                    if let local = map[id] {
                        queueIncomeUpsert(local)
                    }
                    continue
                }

                let income = map[id] ?? {
                    let created = Income(type: "Income")
                    created.id = id
                    context.insert(created)
                    map[id] = created
                    changed = true
                    return created
                }()

                income.type = stringValue(from: data["type"])
                income.emoji = stringValue(from: data["emoji"])
                income.name = stringValue(from: data["name"])
                income.income = doubleValue(from: data["income"])
                income.date = dateValue(from: data["date"])
                income.note = stringValue(from: data["note"])
                clearDirty(kind: .income, id: id)
                changed = true
            }

            if changed {
                try context.save()
            }
        } catch {
            print("❌ Applying full income snapshot failed: \(error.localizedDescription)")
        }
    }

    private func applyTrackerSnapshot(_ snapshot: QuerySnapshot, context: ModelContext) {
        do {
            let locals = try context.fetch(FetchDescriptor<TrackerRecord>())
            var map = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })
            var changed = false

            for change in snapshot.documentChanges {
                let id = change.document.documentID
                switch change.type {
                case .removed:
                    if dirtyDate(kind: .tracker, id: id) == nil, let local = map[id] {
                        context.delete(local)
                        map.removeValue(forKey: id)
                        changed = true
                    }
                case .added, .modified:
                    let data = change.document.data()
                    let remoteUpdatedAt = dateValue(from: data["updatedAt"])
                    if let dirtyAt = dirtyDate(kind: .tracker, id: id), dirtyAt > remoteUpdatedAt {
                        if let local = map[id] {
                            queueTrackerUpsert(local)
                        }
                        continue
                    }

                    let tracker = map[id] ?? {
                        let created = TrackerRecord()
                        created.id = id
                        context.insert(created)
                        map[id] = created
                        changed = true
                        return created
                    }()

                    tracker.type = stringValue(from: data["type"])
                    tracker.name = stringValue(from: data["name"])
                    tracker.subType = stringValue(from: data["subType"])
                    tracker.amount = doubleValue(from: data["amount"])
                    tracker.dueDate = dateValue(from: data["dueDate"])
                    tracker.logoUrl = stringValue(from: data["logoUrl"])
                    clearDirty(kind: .tracker, id: id)
                    changed = true
                }
            }

            if changed {
                try context.save()
            }
        } catch {
            print("❌ Applying tracker snapshot failed: \(error.localizedDescription)")
        }
    }

    private func applyTrackerFullSnapshot(_ snapshot: QuerySnapshot, context: ModelContext) {
        do {
            let locals = try context.fetch(FetchDescriptor<TrackerRecord>())
            var map = Dictionary(uniqueKeysWithValues: locals.map { ($0.id, $0) })
            var changed = false

            for doc in snapshot.documents {
                let id = doc.documentID
                let data = doc.data()
                let remoteUpdatedAt = dateValue(from: data["updatedAt"])

                if let dirtyAt = dirtyDate(kind: .tracker, id: id), dirtyAt > remoteUpdatedAt {
                    if let local = map[id] {
                        queueTrackerUpsert(local)
                    }
                    continue
                }

                let tracker = map[id] ?? {
                    let created = TrackerRecord()
                    created.id = id
                    context.insert(created)
                    map[id] = created
                    changed = true
                    return created
                }()

                tracker.type = stringValue(from: data["type"])
                tracker.name = stringValue(from: data["name"])
                tracker.subType = stringValue(from: data["subType"])
                tracker.amount = doubleValue(from: data["amount"])
                tracker.dueDate = dateValue(from: data["dueDate"])
                tracker.logoUrl = stringValue(from: data["logoUrl"])
                clearDirty(kind: .tracker, id: id)
                changed = true
            }

            if changed {
                try context.save()
            }
        } catch {
            print("❌ Applying full tracker snapshot failed: \(error.localizedDescription)")
        }
    }

    private func timestamp(from date: Date) -> Any {
        Timestamp(date: date)
    }

    private func stringValue(from value: Any?) -> String {
        value as? String ?? ""
    }

    private func doubleValue(from value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return 0
    }

    private func dateValue(from value: Any?) -> Date {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        if let date = value as? Date {
            return date
        }
        return Date()
    }
#else
    private func timestamp(from date: Date) -> Any {
        date
    }
#endif
}
