import SwiftUI

struct GoalsView: View {
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(AppStateViewModel.self) private var appStateViewModel

    var body: some View {
        NavigationStack {
            Text("Goals — \(goalsViewModel.activeGoals.count) active")
                .navigationTitle("Goals")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            goalsViewModel.presentAdd()
                        } label: {
                            Label("Add Goal", systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: .init(
                    get: { goalsViewModel.isGoalFormPresented },
                    set: { goalsViewModel.isGoalFormPresented = $0 }
                )) {
                    GoalFormView(mode: goalsViewModel.goalToEdit.map { .edit($0) } ?? .add)
                }
        }
    }
}
