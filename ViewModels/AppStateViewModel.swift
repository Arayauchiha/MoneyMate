import SwiftData
import SwiftUI
import LocalAuthentication

enum AppTab: String, Hashable, CaseIterable {
    case home
    case transactions
    case goals
    case insights
}

@Observable @MainActor
final class AppStateViewModel {
    // Persistent Preferences
    @ObservationIgnored @AppStorage("user_name") var userName: String = "User"
    @ObservationIgnored @AppStorage("is_biometrics_enabled") var isBiometricsEnabled: Bool = false
    
    // Observable Currency
    var userCurrency: String {
        didSet {
            UserDefaults.standard.set(userCurrency, forKey: "user_currency")
        }
    }
    
    // UI State
    var selectedTab: AppTab = .home
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
    
    init() {
        self.userCurrency = UserDefaults.standard.string(forKey: "user_currency") ?? "₹"
    }

    private(set) var modelContext: ModelContext?

    func configure(context: ModelContext) {
        modelContext = context
        // Initial lock check
        if isBiometricsEnabled {
            isAppLocked = true
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
    
    // MARK: - Authentication
    func authenticate() {
        guard isBiometricsEnabled else {
            isAppLocked = false
            return
        }
        
        // Prevent multiple simultaneous authentication requests
        guard !isAuthenticating else { return }
        
        Task {
            isAuthenticating = true
            defer { isAuthenticating = false }
            
            let context = LAContext()
            // Allow user to cancel and immediately retry
            context.localizedCancelTitle = "Use Passcode"
            
            // LAContext.canEvaluatePolicy requires error pointer in Swift 6, mark as unsafe
            let canEval = unsafe context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
            
            if canEval {
                do {
                    // Use the async version of evaluatePolicy
                    let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock MoneyMate to access your financial data.")
                    if success {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isAppLocked = false
                        }
                    }
                } catch {
                    // Stay locked if auth failed
                }
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
