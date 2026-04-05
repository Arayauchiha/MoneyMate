import SwiftUI

struct AppTabView: View {
    @Environment(AppStateViewModel.self) private var appStateViewModel

    var body: some View {
        @Bindable var appState = appStateViewModel

        TabView(selection: $appState.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }

            Tab("Transactions", systemImage: "list.bullet.rectangle", value: AppTab.transactions) {
                TransactionsView()
            }

            Tab("Goals", systemImage: "target", value: AppTab.goals) {
                GoalsView()
            }

            Tab("Insights", systemImage: "chart.bar.xaxis", value: AppTab.insights) {
                InsightsView()
            }
        }

        .sheet(isPresented: $appState.isAddTransactionPresented) {
            AddEditTransactionView(mode: .add)
        }
    }
}
