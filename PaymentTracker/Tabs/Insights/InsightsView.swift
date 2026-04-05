import SwiftUI

struct InsightsView: View {
    @Environment(InsightsViewModel.self) private var insightsViewModel

    var body: some View {
        NavigationStack {
            Text("Insights — period: \(insightsViewModel.selectedPeriod.label), total: \(insightsViewModel.totalForPeriod.formatted)")
                .navigationTitle("Insights")
        }
        .task { await insightsViewModel.load() }
    }
}
