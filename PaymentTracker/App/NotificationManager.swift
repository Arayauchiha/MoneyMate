import SwiftUI
import UserNotifications

enum ThresholdType {
    case budget80(_ category: String)
    case goal90(_ title: String)
    case goalFilled(_ title: String)

    var title: String {
        switch self {
        case let .budget80(cat): "Budget Warning: \(cat)"
        case let .goal90(t): "Almost there: \(t)"
        case let .goalFilled(t): "Goal Achieved: \(t)"
        }
    }

    var message: String {
        switch self {
        case let .budget80(cat): "You've used 80% of your \(cat) budget cap."
        case let .goal90(t): "You are 90% of the way to '\(t)'."
        case let .goalFilled(t): "Congratulations! You've finished '\(t)'."
        }
    }
}

@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("Notification permission granted.")
            } else if let error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }

    func scheduleDailyReminder(at date: Date) {
        // Cancel existing daily reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        let content = UNMutableNotificationContent()
        content.title = "MoneyMate Check-in"
        content.body = "Time for a quick check-in?"
        content.sound = .default

        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
    }

    func sendThresholdAlert(for type: ThresholdType) {
        let content = UNMutableNotificationContent()
        content.title = "MoneyMate Update"
        content.subtitle = type.title
        content.body = type.message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}
