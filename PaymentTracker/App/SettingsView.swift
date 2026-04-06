import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allGoals: [Goal]
    @Query private var allCategories: [Category]
    
    @State private var includeArchived: Bool = true
    @State private var exportFile: ExportFile?
    @State private var isExporting: Bool = false
    @State private var isResetAlertPresented: Bool = false
    @State private var isReminderConfirmationPresented: Bool = false
    @State private var hasModifiedReminders: Bool = false
    @State private var didDismissWithDone: Bool = false
    
    let currencies = ["₹", "$", "€", "£", "¥"]

    var body: some View {
        @Bindable var appState = appStateViewModel
        
        NavigationStack {
            Form {
                Section {
                    Picker("Default Currency", selection: $appState.userCurrency) {
                        ForEach(currencies, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Finances")
                } footer: {
                    Text("This currency symbol will be applied to all balance and transaction displays.")
                }

                Section {
                    Picker("Theme", selection: $appState.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.label).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose between light, dark, or system-synced visual modes.")
                }

                Section {
                    NavigationLink {
                        UserManualView()
                    } label: {
                        Label("User Manual", systemImage: "book.pages")
                    }
                } header: {
                    Text("Support")
                } footer: {
                    Text("A detailed guide on how to master your money with MoneyMate.")
                }

                Section {
                    Toggle(isOn: $appState.isBiometricsEnabled) {
                        Label("Enable Face ID", systemImage: "faceid")
                    }
                    .onChange(of: appState.isBiometricsEnabled) { old, new in
                        if new {
                            appState.authenticate()
                        }
                    }
                } header: {
                    Text("Security")
                } footer: {
                    Text("When enabled, MoneyMate will automatically lock whenever you leave the app.")
                }

                Section {
                    if !appState.isNotificationAuthorized {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Notifications Disabled")
                                    .font(.subheadline.bold())
                                Text("Enable them in System Settings to receive alerts.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Toggle(isOn: $appState.isDailyReminderEnabled) {
                        Label("Daily Log Reminder", systemImage: "bell.badge")
                    }
                    .onChange(of: appState.isDailyReminderEnabled) { _, _ in
                        hasModifiedReminders = true
                    }
                    
                    if appState.isDailyReminderEnabled {
                        DatePicker("Reminder Time", selection: $appState.dailyReminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: appState.dailyReminderTime) { _, _ in
                                hasModifiedReminders = true
                            }
                    }
                    
                    Toggle(isOn: $appState.isGoalAlertsEnabled) {
                        Label("Goal & Budget Alerts", systemImage: "target")
                    }
                    
                    Button {
                        NotificationManager.shared.sendThresholdAlert(for: .budget80("Demo Category"))
                    } label: {
                        Label("Test Notification", systemImage: "bell.fill")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Stay on track with daily reminders and instant alerts for goal milestones and budget warnings.")
                }

                Section {
                    Toggle("Include Archived Transactions", isOn: $includeArchived)
                    
                    Button {
                        isExporting = true
                        Task {
                            // Run on background thread to prevent UI freezing
                            let url = await generateCSV()
                            await MainActor.run {
                                if let url = url {
                                    exportFile = ExportFile(url: url)
                                }
                                isExporting = false
                            }
                        }
                    } label: {
                        HStack {
                            Label("Export Data to CSV", systemImage: "square.and.arrow.up")
                                .foregroundStyle(.blue)
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isExporting)
                } header: {
                    Text("Data Export")
                } footer: {
                    Text("Export your information for use in external tools like Excel or Google Sheets.")
                }

                Section {
                    Button(role: .destructive) {
                        isResetAlertPresented = true
                    } label: {
                        Label("Hard Reset Data", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        if hasModifiedReminders {
                            if appStateViewModel.isDailyReminderEnabled {
                                NotificationManager.shared.scheduleDailyReminder(at: appStateViewModel.dailyReminderTime)
                                // Show confirmation and then dismiss in the alert closure
                                isReminderConfirmationPresented = true
                            } else {
                                NotificationManager.shared.cancelDailyReminder()
                                dismiss()
                            }
                        } else {
                            dismiss()
                        }
                    }.fontWeight(.bold)
                }
            }
            .alert("Reminder Scheduled", isPresented: $isReminderConfirmationPresented) {
                Button("Got it!", role: .cancel) { 
                    dismiss()
                }
            } message: {
                Text("Your daily log reminder has been set for \(appStateViewModel.dailyReminderTime.formatted(date: .omitted, time: .shortened)).")
            }
            .alert("Are you absolutely sure?", isPresented: $isResetAlertPresented) {
                Button("Delete All Data", role: .destructive) {
                    performHardReset()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action will permanently delete all your transactions, goals, and custom categories. This cannot be undone.")
            }
            .sheet(item: $exportFile) { file in
                ActivityView(activityItems: [file.url])
                    .presentationDetents([.medium, .large])
            }
        }
        .preferredColorScheme(appStateViewModel.appearance.colorScheme)
    }

    private func performHardReset() {
        // We use a safe, coordinated deletion to ensure all relationships are cleaned and UI updates correctly.
        do {
            // 1. Delete all transactions first (breaks links to goals)
            for txn in allTransactions {
                modelContext.delete(txn)
            }
            
            // 2. Delete all goals
            for goal in allGoals {
                modelContext.delete(goal)
            }
            
            // 3. Delete custom categories
            for cat in allCategories {
                modelContext.delete(cat)
            }
            
            try modelContext.save()
            dismiss()
        } catch {
            appStateViewModel.showAlert(title: "Reset Failed", message: error.localizedDescription)
        }
    }

    private func generateCSV() async -> URL? {
        let targets = includeArchived ? allTransactions : allTransactions.filter { !$0.isArchived }
        
        guard !targets.isEmpty else {
            await MainActor.run {
                appStateViewModel.showAlert(title: "No Data", message: "There are no transactions to export.")
            }
            return nil
        }
        
        // Columns: Date, Time, Title, Amount, Type, Category, Note
        var csvString = "Date,Time,Title,Amount,Type,Category,Note\n"
        
        for txn in targets {
            let date = txn.date.formatted(.dateTime.day().month().year())
            let time = txn.date.formatted(.dateTime.hour().minute())
            let title = txn.title.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ")
            let amount = txn.money.amount.description
            let type = txn.type.rawValue
            let category = txn.category?.name ?? "None"
            let note = txn.note.replacingOccurrences(of: ",", with: " ").replacingOccurrences(of: "\n", with: " ")
            
            let row = "\(date),\(time),\(title),\(amount),\(type),\(category),\(note)\n"
            csvString.append(row)
        }
        
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("MoneyMate_Export_\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            return path
        } catch {
            await MainActor.run {
                appStateViewModel.showAlert(title: "Export Failed", message: error.localizedDescription)
            }
            return nil
        }
    }
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
