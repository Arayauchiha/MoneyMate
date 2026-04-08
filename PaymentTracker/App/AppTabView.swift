import SwiftUI
import SwiftData

struct AppTabView: View {
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(TransactionViewModel.self) private var transactionViewModel
    @Environment(GoalsViewModel.self) private var goalsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var appState = appStateViewModel
        let selection = Binding<AppTab>(
            get: { appState.selectedTab },
            set: { newValue in
                if newValue == .add {
                    appState.isAddTransactionPresented = true
                } else {
                    appStateViewModel.selectedTab = newValue
                }
            }
        )

        ZStack {
            FintechDesign.Background()

            TabView(selection: selection) {
                Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                    HomeView()
                }

                Tab("Transactions", systemImage: "list.bullet.rectangle", value: AppTab.transactions) {
                    TransactionsView()
                }

                // Global Action Tab (Leveraging Search Role for 'Separated' Placement)
                Tab("Add", systemImage: "plus", value: AppTab.add, role: .search) {
                    Color.clear
                }

                Tab("Goals", systemImage: "target", value: AppTab.goals) {
                    GoalsView()
                }

                Tab("Insights", systemImage: "chart.bar.xaxis", value: AppTab.insights) {
                    InsightsView()
                }
            }
            .tint(Color(hex: "10B981")) // Fintech green for active tab
            .tabBarMinimizeBehavior(.onScrollDown)
            .toolbar(appState.isTabBarHidden ? .hidden : .visible, for: .tabBar)
            .animation(.default, value: appState.isTabBarHidden)
            .blur(radius: appState.isAppLocked ? 15 : 0)

            // Blur everything when locked
            if appState.isAppLocked {
                ZStack {
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        VStack(spacing: 8) {
                            Text("Face ID Required")
                                .font(.title3.bold())
                            
                            Text("Unlock to access your secure financial data.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            appState.authenticate()
                        } label: {
                            HStack {
                                Image(systemName: "faceid")
                                Text("Unlock with Face ID")
                            }
                            .fontWeight(.semibold)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 24)
                            .background(Color.blue.gradient)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 20)
                    }
                }
                .transition(.opacity)
                .zIndex(2) // Ensure lock screen is top-most
            }
        }
        .sheet(isPresented: $appState.isAddTransactionPresented) {
            AddEditTransactionView(mode: .add)
                .environment(goalsViewModel)
                .environment(transactionViewModel)
                .environment(appStateViewModel)
                .modelContext(modelContext)
        }
        .sheet(isPresented: .init(
            get: { transactionViewModel.isAddEditSheetPresented },
            set: { transactionViewModel.isAddEditSheetPresented = $0 }
        )) {
            AddEditTransactionView(
                mode: transactionViewModel.transactionToEdit.map { .edit($0) } ?? .add
            )
            .environment(goalsViewModel)
            .environment(transactionViewModel)
            .environment(appStateViewModel)
            .modelContext(modelContext)
        }
        .sheet(isPresented: $appState.isSettingsPresented) {
            SettingsView()
                .environment(goalsViewModel)
                .environment(transactionViewModel)
                .environment(appStateViewModel)
                .modelContext(modelContext)
        }
        .onChange(of: scenePhase) { old, new in
            if new == .background || new == .inactive {
                appState.lockApp()
            } else if new == .active {
                // If it was already locked, trigger authentication automatically
                if appState.isAppLocked {
                    appState.authenticate()
                }
            }
        }
        .onAppear {
            if appState.isAppLocked {
                appState.authenticate()
            }
        }
    }
}
