import Foundation
import SwiftData

enum AppNotificationType: String, Codable {
    case budget
    case goal
    case weekly
    case reminder
    case system

    var icon: String {
        switch self {
        case .budget: "exclamationmark.triangle.fill"
        case .goal: "target"
        case .weekly: "chart.bar.fill"
        case .reminder: "bell.fill"
        case .system: "info.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .budget: "FF6B6B"
        case .goal: "10B981"
        case .weekly: "6366F1"
        case .reminder: "F59E0B"
        case .system: "64748B"
        }
    }
}

@Model
class AppNotification {
    var id: UUID
    var title: String
    var body: String
    var date: Date
    var isRead: Bool
    var typeRaw: String

    var type: AppNotificationType {
        AppNotificationType(rawValue: typeRaw) ?? .system
    }

    init(title: String, body: String, type: AppNotificationType, date: Date = .now) {
        id = UUID()
        self.title = title
        self.body = body
        typeRaw = type.rawValue
        self.date = date
        isRead = false
    }
}
