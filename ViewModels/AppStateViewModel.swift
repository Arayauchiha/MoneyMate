import LocalAuthentication
import SwiftData
import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case home
    case transactions
    case add
    case goals
    case insights
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String {
        rawValue
    }

    var label: String {
        rawValue
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable @MainActor
final class AppStateViewModel {
    // Persistent Preferences
    @ObservationIgnored @AppStorage("user_name") private var _userName: String = "User"
    var userName: String {
        get { _userName }
        set { _userName = newValue }
    }

    @ObservationIgnored @AppStorage("is_biometrics_enabled") var isBiometricsEnabled: Bool = false

    var appearance: AppAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: "app_appearance") }
    }

    var isDailyReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(isDailyReminderEnabled, forKey: "is_daily_reminder_enabled") }
    }

    var isGoalAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(isGoalAlertsEnabled, forKey: "is_goal_alerts_enabled") }
    }

    private var dailyReminderTimeRaw: Double {
        didSet { UserDefaults.standard.set(dailyReminderTimeRaw, forKey: "daily_reminder_time_raw") }
    }

    var isNotificationAuthorized: Bool = true

    /// Observable Currency
    var userCurrency: String {
        didSet {
            UserDefaults.standard.set(userCurrency, forKey: "user_currency")
        }
    }

    /// UI State
    var selectedTab: AppTab = .home {
        didSet {
            if selectedTab != .add {
                previousTab = oldValue
            }
        }
    }

    var previousTab: AppTab = .home
    var isTabBarHidden: Bool = false
    var isAddTransactionPresented: Bool = false
    var isAddEditGoalPresented: Bool = false
    var isSettingsPresented: Bool = false

    // Security State
    var isAppLocked: Bool = false
    var isAuthenticating: Bool = false

    // Global Alerts
    var alertTitle: String = ""
    var alertMessage: String = ""
    var isAlertPresented: Bool = false

    var dailyReminderTime: Date {
        get { Date(timeIntervalSince1970: dailyReminderTimeRaw) }
        set { dailyReminderTimeRaw = newValue.timeIntervalSince1970 }
    }

    init() {
        userCurrency = UserDefaults.standard.string(forKey: "user_currency") ?? "₹"
        let savedAppearance = UserDefaults.standard.string(forKey: "app_appearance") ?? AppAppearance.system.rawValue
        appearance = AppAppearance(rawValue: savedAppearance) ?? .system
        isDailyReminderEnabled = UserDefaults.standard.bool(forKey: "is_daily_reminder_enabled")
        isGoalAlertsEnabled = UserDefaults.standard.object(forKey: "is_goal_alerts_enabled") as? Bool ?? true
        dailyReminderTimeRaw = UserDefaults.standard.double(forKey: "daily_reminder_time_raw")
        if dailyReminderTimeRaw == 0 {
            dailyReminderTimeRaw = Date().timeIntervalSince1970
        }
    }

    private(set) var modelContext: ModelContext?

    func configure(context: ModelContext) {
        modelContext = context
        if isBiometricsEnabled {
            isAppLocked = true
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                self.isNotificationAuthorized = (status == .authorized || status == .provisional)
            }
        }
    }

    func navigate(to tab: AppTab) {
        selectedTab = tab
    }

    func presentAddTransaction() {
        isAddTransactionPresented = true
    }

    func showAlert(title: String, message: String = "") {
        alertTitle = title
        alertMessage = message
        isAlertPresented = true
    }

    func authenticate() {
        guard isBiometricsEnabled else {
            isAppLocked = false
            return
        }

        guard !isAuthenticating else { return }

        Task {
            isAuthenticating = true
            defer { isAuthenticating = false }

            let context = LAContext()
            context.localizedCancelTitle = "Use Passcode"

            let canEval = unsafe context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)

            if canEval {
                do {
                    let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock MoneyMate to access your financial data.")
                    if success {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isAppLocked = false
                        }
                    }
                } catch {}
            } else {
                isAppLocked = false
            }
        }
    }

    func lockApp() {
        if isBiometricsEnabled {
            isAppLocked = true
        }
    }
}
