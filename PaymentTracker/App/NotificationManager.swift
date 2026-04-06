import UserNotifications
import SwiftUI

enum ThresholdType {
    case budget80(_ category: String)
    case goal90(_ title: String)
    case goalFilled(_ title: String)
    
    var title: String {
        switch self {
        case .budget80(let cat): return "Budget Warning: \(cat)"
        case .goal90(let t): return "Almost there: \(t)"
        case .goalFilled(let t): return "Goal Achieved: \(t)"
        }
    }
    
    var message: String {
        switch self {
        case .budget80(let cat): return "You've used 80% of your \(cat) budget cap. Time to slow down!"
        case .goal90(let t): return "You are 90% of the way to '\(t)'. You've got this!"
        case .goalFilled(let t): return "Congratulations! You've successfully finished your '\(t)' goal."
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
            } else if let error = error {
                print("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleDailyReminder(at date: Date) {
        // Cancel existing daily reminders
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])
        
        let content = UNMutableNotificationContent()
        content.title = "MoneyMate Check-in"
        content.body = "Time for a quick check-in? 5 minutes now saves hours of tracking later."
        content.sound = .default
        
        // We use Gregorian calendar for precise minute matching
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents([.hour, .minute], from: date)
        components.second = 0 // Ensure it triggers exactly at the turn of the minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        let hr = components.hour ?? 0
        let min = components.minute ?? 0
        
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error.localizedDescription)")
            } else {
                print("Daily reminder scheduled successfully for \(hr):\(min)")
            }
        }
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
        
        // Send immediately
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Delegate Actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // This allows banner/sound/list to show even when the app is in the foreground
        completionHandler([.banner, .list, .sound])
    }
}
