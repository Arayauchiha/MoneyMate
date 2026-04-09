import Foundation
import SwiftData

@Model
final class Transaction: Identifiable {
    var id: UUID
    var type: TransactionType
    var date: Date
    var title: String = ""
    var note: String = ""
    var isArchived: Bool = false
    var archivedDate: Date?
    var repeatFrequency: String = "never" // never, daily, weekly, monthly, yearly
    var isScheduled: Bool = false

    /// Transient: set by ViewModel to show a recurring occurrence at a different date without creating an unmanaged proxy.
    @Transient var displayDate: Date?

    /// The date to use for display purposes (occurrence date if set, otherwise actual stored date).
    var effectiveDate: Date {
        displayDate ?? date
    }

    private var amountRaw: String

    var category: Category?
    var linkedGoal: Goal?

    init(
        id: UUID = .init(),
        amount: Money,
        type: TransactionType,
        category: Category? = nil,
        linkedGoal: Goal? = nil,
        date: Date = .now,
        title: String = "",
        note: String = "",
        repeatFrequency: String = "never",
        isScheduled: Bool = false
    ) {
        self.id = id
        amountRaw = "\(amount.amount)"
        self.type = type
        self.category = category
        self.linkedGoal = linkedGoal
        self.date = date
        self.title = title
        self.note = note
        self.repeatFrequency = repeatFrequency
        self.isScheduled = isScheduled
    }

    var money: Money {
        get {
            let d = Decimal(string: amountRaw) ?? .zero
            return Money(d)
        }
        set { amountRaw = "\(newValue.amount)" }
    }

    @MainActor
    var signedMoney: Money {
        Money(money.amount * type.balanceMultiplier)
    }

    @MainActor
    var formattedAmount: String {
        switch type {
        case .income: "+\(money.formatted)"
        case .expense: "-\(money.formatted)"
        case .transfer: money.formatted
        }
    }

    @MainActor
    var formattedAmountCompact: String {
        switch type {
        case .income: "+\(money.formattedCompact)"
        case .expense: "-\(money.formattedCompact)"
        case .transfer: money.formattedCompact
        }
    }

    func occurrences(upTo date: Date) -> Int {
        guard repeatFrequency != "never" else {
            return self.date <= date ? 1 : 0
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: self.date)
        let end = calendar.startOfDay(for: date)

        guard start <= end else { return 0 }

        let components: Calendar.Component
        switch repeatFrequency {
        case "daily": components = .day
        case "weekly": components = .weekOfYear
        case "monthly": components = .month
        case "yearly": components = .year
        default: return 1
        }

        let diff = calendar.dateComponents([components], from: start, to: end)
        return (diff.value(for: components) ?? 0) + 1
    }

    /// Returns every date this transaction occurs on from its origin up to `cutoff`.
    func occurrenceDates(upTo cutoff: Date) -> [Date] {
        guard repeatFrequency != "never" else {
            return date <= cutoff ? [date] : []
        }

        let calendar = Calendar.current
        var dates: [Date] = []
        var current = date

        let component: Calendar.Component
        switch repeatFrequency {
        case "daily": component = .day
        case "weekly": component = .weekOfYear
        case "monthly": component = .month
        case "yearly": component = .year
        default: return [date]
        }

        while current <= cutoff {
            dates.append(current)
            guard let next = calendar.date(byAdding: component, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    /// Creates a display-only in-memory occurrence of this transaction on a different date.
    /// This object is NEVER inserted into any model context — it is purely for UI display.
    func virtualOccurrence(on occurrenceDate: Date) -> Transaction {
        let virtual = Transaction(
            amount: money,
            type: type,
            category: category,
            linkedGoal: linkedGoal,
            date: occurrenceDate,
            title: title,
            note: note,
            repeatFrequency: repeatFrequency
        )
        virtual.displayDate = occurrenceDate
        return virtual
    }
}

extension Transaction {
    @MainActor
    static func predicate(from start: Date, to end: Date) -> Predicate<Transaction> {
        return #Predicate<Transaction> { $0.date >= start && $0.date <= end }
    }

    @MainActor
    static func predicate(type: TransactionType) -> Predicate<Transaction> {
        let raw = type.rawValue
        return #Predicate<Transaction> { $0.type.rawValue == raw }
    }
}
