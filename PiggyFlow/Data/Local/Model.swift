import Foundation
import SwiftData

@Model
final class Expense {
    var id: String = UUID().uuidString  // ✅ default value fixes CloudKit issue
    var type:String = " "
    var emoji: String = ""
    var name: String = ""
    var price: Double = 0
    var date: Date = Date()
    var note: String = ""

    init(type:String, emoji: String = "", name: String = "", price: Double = 0, date: Date = Date(), note: String = "") {
        self.type = type
        self.emoji = emoji
        self.name = name
        self.price = price
        self.date = date
        self.note = note
    }
}

@Model
final class Income {
    var id: String = UUID().uuidString  // ✅ default value fixes CloudKit issue
    var type:String = " "
    var emoji: String = ""
    var name: String = ""
    var income: Double = 0
    var date: Date = Date()
    var note: String = ""

    init(type:String, emoji: String = "", name: String = "", income: Double = 0, date: Date = Date(), note: String = "") {
        self.type = type
        self.emoji = emoji
        self.name = name
        self.income = income
        self.date = date
        self.note = note
    }
}

@Model
final class UserCategory {
    var id: String = UUID().uuidString
    var name: String = ""
    var emoji: String = ""

    init(name: String, emoji: String = "") {
        self.name = name
        self.emoji = emoji
    }
}
