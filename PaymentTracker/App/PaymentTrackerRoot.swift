import SwiftData
import SwiftUI

struct MoneyMateRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var homeViewModel = HomeViewModel()
    @State private var transactionViewModel = TransactionViewModel()
    @State private var goalsViewModel = GoalsViewModel()
    @State private var insightsViewModel = InsightsViewModel()
    @State private var appStateViewModel = AppStateViewModel()

    var body: some View {
        ZStack {
            AppTabView()
                .blur(radius: appStateViewModel.isAppLocked ? 20 : 0)
                .overlay {
                    if appStateViewModel.isAppLocked {
                        lockScreen
                    }
                }
        }
        .preferredColorScheme(appStateViewModel.appearance.colorScheme)
        .environment(homeViewModel)
        .environment(transactionViewModel)
        .environment(goalsViewModel)
        .environment(insightsViewModel)
        .environment(appStateViewModel)
        .task {
            // Initial configuration
            appStateViewModel.configure(context: modelContext)
            homeViewModel.configure(context: modelContext)
            transactionViewModel.configure(context: modelContext)
            goalsViewModel.configure(context: modelContext, appState: appStateViewModel)
            insightsViewModel.configure(context: modelContext)

            transactionViewModel.cleanupOldArchives()

            // Notification Permissions & Scheduling
            NotificationManager.shared.requestPermission()
            if appStateViewModel.isDailyReminderEnabled {
                NotificationManager.shared.scheduleDailyReminder(at: appStateViewModel.dailyReminderTime)
            }

            // Initial auth if enabled
            if appStateViewModel.isBiometricsEnabled {
                appStateViewModel.authenticate()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                appStateViewModel.lockApp()
            } else if newPhase == .active {
                if appStateViewModel.isAppLocked, appStateViewModel.isBiometricsEnabled, !appStateViewModel.isAuthenticating {
                    appStateViewModel.authenticate()
                }
            }
        }
    }

    private var lockScreen: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("MoneyMate Locked")
                    .font(.title2).bold()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    appStateViewModel.authenticate()
                } label: {
                    Text("Unlock with FaceID")
                        .fontWeight(.bold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
