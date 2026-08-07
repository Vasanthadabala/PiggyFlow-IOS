import SwiftUI

/// Canonical SF Symbol names.
///
/// The same concept was being spelled differently across screens — the tab bar used
/// `doc.text.fill` for expenses while the shortcut row used `doc.text`, and "trending"
/// appeared as both `chart.line.uptrend.xyaxis` and `chart.xyaxis.line`. Naming them once
/// keeps an icon consistent everywhere it appears.
enum AppIcon {

    // MARK: - Tab bar
    enum Tab {
        public static let home = "house"
        public static let expenses = "doc.text"
        public static let tracker = "calendar.badge.checkmark"
        public static let reports = "chart.bar"
    }

    // MARK: - Navigation & chrome
    enum Nav {
        public static let back = "chevron.left"
        public static let forward = "chevron.right"
        public static let close = "xmark"
        public static let menu = "line.3.horizontal"
        public static let filter = "line.3.horizontal.decrease"
        public static let more = "ellipsis"
        public static let search = "magnifyingglass"
        public static let settings = "gearshape"
        public static let notifications = "bell"
        public static let expand = "chevron.down"
    }

    // MARK: - Actions
    enum Action {
        public static let add = "plus"
        public static let addCircle = "plus.circle.fill"
        public static let edit = "square.and.pencil"
        public static let delete = "trash.fill"
        public static let share = "square.and.arrow.up"
        public static let export = "square.and.arrow.down"
        public static let scan = "camera.fill"
        public static let reorder = "arrow.up.arrow.down"
        public static let refresh = "arrow.triangle.2.circlepath"
        public static let view = "eye.fill"
        public static let hide = "eye.slash"
        public static let show = "eye"
    }

    // MARK: - Finance concepts
    enum Finance {
        public static let bank = "building.columns.fill"
        public static let creditCard = "creditcard.fill"
        public static let cash = "banknote.fill"
        public static let wallet = "wallet.pass.fill"
        public static let income = "arrow.down.left"
        public static let expense = "arrow.up.right"
        public static let budget = "target"
        public static let goal = "flag.fill"
        public static let subscription = "repeat.circle.fill"
        public static let emi = "building.2.fill"
        public static let due = "timer"
    }

    // MARK: - Charts & insights
    enum Chart {
        public static let trend = "chart.line.uptrend.xyaxis"
        public static let bar = "chart.bar.fill"
        public static let pie = "chart.pie.fill"
        public static let insight = "lightbulb.fill"
        public static let report = "doc.text.fill"
    }

    // MARK: - Categories
    enum Category {
        public static let food = "fork.knife"
        public static let shopping = "cart.fill"
        public static let fuel = "fuelpump.fill"
        public static let utilities = "bolt.fill"
        public static let transport = "bus.fill"
        public static let entertainment = "star.fill"
        public static let other = "ellipsis"
    }

    // MARK: - Status
    enum Status {
        public static let success = "checkmark.circle.fill"
        public static let warning = "exclamationmark.circle.fill"
        public static let verified = "checkmark.seal.fill"
        public static let secure = "lock.fill"
    }
}
