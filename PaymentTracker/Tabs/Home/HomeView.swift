import SwiftUI

struct HomeView: View {
    @Environment(HomeViewModel.self) private var homeViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    var body: some View {
        NavigationStack {
            Text("Home — balance: \(homeViewModel.totalBalance.formatted)")
                .navigationTitle("Overview")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            appStateViewModel.presentAddTransaction()
                        } label: {
                            Label("Add Transaction", systemImage: "plus")
                        }
                    }
                }
        }
        .task { homeViewModel.refresh() }
    }
}
