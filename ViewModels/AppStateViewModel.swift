import SwiftData
import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case home
    case transactions
    case goals
    case insights
}

@Observable
final class AppStateViewModel {
    var selectedTab: AppTab = .home
    var isTabBarHidden: Bool = false

    var isAddTransactionPresented: Bool = false

    var alertTitle: String = ""
    var alertMessage: String = ""
    var isAlertPresented: Bool = false

    private(set) var modelContext: ModelContext?

    func configure(context: ModelContext) {
        modelContext = context
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
}
