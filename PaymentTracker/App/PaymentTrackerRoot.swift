import SwiftData
import SwiftUI

struct PaymentTrackerRoot: View {
    @Environment(\.modelContext) private var modelContext

    @State private var homeViewModel = HomeViewModel()
    @State private var transactionViewModel = TransactionViewModel()
    @State private var goalsViewModel = GoalsViewModel()
    @State private var insightsViewModel = InsightsViewModel()
    @State private var appStateViewModel = AppStateViewModel()

    var body: some View {
        AppTabView()

            .task {
                homeViewModel.configure(context: modelContext)
                transactionViewModel.configure(context: modelContext)
                goalsViewModel.configure(context: modelContext)
                insightsViewModel.configure(context: modelContext)
                appStateViewModel.configure(context: modelContext)
            }

            .environment(homeViewModel)
            .environment(transactionViewModel)
            .environment(goalsViewModel)
            .environment(insightsViewModel)
            .environment(appStateViewModel)
    }
}
