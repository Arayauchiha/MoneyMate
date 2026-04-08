import Foundation
import SwiftData

enum AppNotificationType: String, Codable {
    case budget   = "budget"
    case goal     = "goal"
    case weekly   = "weekly"
    case reminder = "reminder"
    case system   = "system"

    var icon: String {
        switch self {
        case .budget:   return "exclamationmark.triangle.fill"
        case .goal:     return "target"
        case .weekly:   return "chart.bar.fill"
        case .reminder: return "bell.fill"
        case .system:   return "info.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .budget:   return "FF6B6B"
        case .goal:     return "10B981"
        case .weekly:   return "6366F1"
        case .reminder: return "F59E0B"
        case .system:   return "64748B"
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
        self.id = UUID()
        self.title = title
        self.body = body
        self.typeRaw = type.rawValue
        self.date = date
        self.isRead = false
    }
}
