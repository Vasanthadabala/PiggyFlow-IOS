import SwiftData

struct CloudSyncManager {
    static func syncLocalDataToCloud(localContainer: ModelContainer, cloudContainer: ModelContainer) {
        let context = localContainer.mainContext
        let cloudContext = cloudContainer.mainContext
        
        do {
            let expenses = try context.fetch(FetchDescriptor<Expense>())
            let incomes = try context.fetch(FetchDescriptor<Income>())
            
            // ✅ Recreate data to avoid context ownership conflict
            for expense in expenses {
                let newExpense = Expense(
                    type: expense.type,
                    emoji: expense.emoji,
                    name: expense.name,
                    price: expense.price,
                    date: expense.date,
                    note: expense.note
                )
                cloudContext.insert(newExpense)
            }
            
            for income in incomes {
                let newIncome = Income(
                    type: income.type,
                    emoji: income.emoji,
                    name: income.name,
                    income: income.income,
                    date: income.date,
                    note: income.note
                )
                cloudContext.insert(newIncome)
            }
            
            try cloudContext.save()
            print("✅ Local data synced to iCloud!")
        } catch {
            print("❌ Failed to sync data: \(error)")
        }
    }
}
