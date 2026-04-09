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
        case .income: Color(hex: "10B981") // Premium Green
        case .expense: .red
        case .transfer: .primary // Neutral for funding
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
    case dailyLimit

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .savings: "Savings goal"
        case .noSpend: "No-spend challenge"
        case .budgetCap: "Budget cap"
        case .dailyLimit: "Daily spending limit"
        }
    }

    var description: String {
        switch self {
        case .savings: "Save a target amount by a deadline"
        case .noSpend: "Avoid spending in selected categories"
        case .budgetCap: "Keep monthly spending under a limit"
        case .dailyLimit: "Keep your daily spend under a set amount"
        }
    }

    var systemImage: String {
        switch self {
        case .savings: "banknote"
        case .noSpend: "nosign"
        case .budgetCap: "gauge.with.dots.needle.67percent"
        case .dailyLimit: "calendar.day.timeline.left"
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
        case .onTrack: .blue
        case .atRisk: .orange
        case .achieved: .green
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

        switch self {
        case .week:
            var current = calendar.startOfDay(for: today)
            while calendar.component(.weekday, from: current) != 2 {
                current = calendar.date(byAdding: .day, value: -1, to: current)!
            }

            let start = current
            let sunday = calendar.date(byAdding: .day, value: 6, to: start)!
            let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sunday)!

            return (start, end)

        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)

        case .threeMonths:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let start = calendar.date(byAdding: .month, value: -2, to: monthStart)!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)!
            return (start, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)

        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: today))!
            let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start)!
            return (start, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end)!)
        }
    }
}
