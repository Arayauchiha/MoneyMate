import SwiftUI

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income
    case expense
    case transfer

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .transfer: "Transfer"
        }
    }

    var balanceMultiplier: Decimal {
        switch self {
        case .income: 1
        case .expense: -1
        case .transfer: 0
        }
    }

    var color: Color {
        switch self {
        case .income: .green
        case .expense: .red
        case .transfer: .blue
        }
    }

    var systemImage: String {
        switch self {
        case .income: "arrow.down.circle.fill"
        case .expense: "arrow.up.circle.fill"
        case .transfer: "arrow.left.arrow.right.circle.fill"
        }
    }
}

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case savings
    case noSpend
    case budgetCap

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .savings: "Savings goal"
        case .noSpend: "No-spend challenge"
        case .budgetCap: "Budget cap"
        }
    }

    var description: String {
        switch self {
        case .savings: "Save a target amount by a deadline"
        case .noSpend: "Avoid spending in selected categories"
        case .budgetCap: "Keep monthly spending under a limit"
        }
    }

    var systemImage: String {
        switch self {
        case .savings: "banknote"
        case .noSpend: "nosign"
        case .budgetCap: "gauge.with.dots.needle.67percent"
        }
    }
}

enum GoalStatus {
    case onTrack
    case atRisk
    case achieved
    case failed

    var label: String {
        switch self {
        case .onTrack: "On track"
        case .atRisk: "At risk"
        case .achieved: "Achieved"
        case .failed: "Failed"
        }
    }

    var color: Color {
        switch self {
        case .onTrack: .green
        case .atRisk: .orange
        case .achieved: .blue
        case .failed: .red
        }
    }

    var systemImage: String {
        switch self {
        case .onTrack: "checkmark.circle"
        case .atRisk: "exclamationmark.triangle"
        case .achieved: "trophy.fill"
        case .failed: "xmark.circle"
        }
    }
}

enum TimePeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case threeMonths
    case year

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .week: "This week"
        case .month: "This month"
        case .threeMonths: "3 months"
        case .year: "This year"
        }
    }

    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = Date()
        let start: Date = switch self {
        case .week:
            calendar.date(byAdding: .day, value: -6, to: today)!
        case .month:
            calendar.date(byAdding: .month, value: -1, to: today)!
        case .threeMonths:
            calendar.date(byAdding: .month, value: -3, to: today)!
        case .year:
            calendar.date(byAdding: .year, value: -1, to: today)!
        }
        return (start, today)
    }
}
