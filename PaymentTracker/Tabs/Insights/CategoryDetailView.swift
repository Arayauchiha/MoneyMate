import SwiftUI
import SwiftData

enum DetailResolution: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .day: return "calendar.day.timeline.left"
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        }
    }
}

struct CategoryDetailView: View {
    @Environment(TransactionViewModel.self) private var transactionViewModel
    let category: Category?
    
    @State private var currentStart: Date
    @State private var currentEnd: Date
    @State private var resolution: DetailResolution
    @State private var pickerDate: Date // Independent state for the picker to prevent auto-snapping to 1st
    
    @State private var isPeriodPickerPresented = false
    
    @Query private var transactions: [Transaction]
    
    init(category: Category?, startDate: Date, endDate: Date) {
        self.category = category
        self._currentStart = State(initialValue: startDate)
        self._currentEnd = State(initialValue: endDate)
        self._pickerDate = State(initialValue: startDate)
        
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        if days == 0 { self._resolution = State(initialValue: .day) }
        else if days <= 7 { self._resolution = State(initialValue: .week) }
        else { self._resolution = State(initialValue: .month) }
        
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        _transactions = Query(descriptor)
    }
    
    private var filteredTransactions: [Transaction] {
        transactions.filter { txn in
            txn.type == .expense &&
            txn.date >= currentStart &&
            txn.date <= currentEnd &&
            (category == nil || txn.category?.id == category?.id)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Card
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        Circle()
                            .fill((category?.color ?? .blue).gradient)
                            .frame(width: 72, height: 72)
                            .overlay {
                                Image(systemName: category?.iconName ?? resolution.icon)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: (category?.color ?? .blue).opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category?.name ?? (resolution == .month ? "Monthly Breakdown" : resolution == .week ? "Weekly Breakdown" : "Daily Breakdown"))
                                .font(.title)
                                .fontWeight(.black)
                            
                            HStack(spacing: 6) {
                                Image(systemName: resolution.icon)
                                    .font(.caption)
                                Text(headerDateString)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        statCard(
                            title: "Total Outflow",
                            value: Money(filteredTransactions.reduce(0) { $0 + $1.money.amount }).formatted,
                            icon: "arrow.up.circle.fill",
                            color: .red
                        )
                        
                        statCard(
                            title: "Transactions",
                            value: "\(filteredTransactions.count)",
                            icon: "list.bullet.circle.fill",
                            color: .blue
                        )
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: 10)
                )
                
                // Transaction List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Transaction Log")
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .foregroundStyle(.secondary)
                    
                    if filteredTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.quaternary)
                            Text("No activity for this period.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    } else {
                        ForEach(filteredTransactions) { txn in
                            Button {
                                transactionViewModel.presentEdit(txn)
                            } label: {
                                TransactionRow(transaction: txn)
                                    .padding()
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .cornerRadius(20)
                                    .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(category?.name ?? "Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPeriodPickerPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(.primary) // Remove the blur/background
                        .padding(4)
                }
            }
        }
        .sheet(isPresented: $isPeriodPickerPresented) {
            filterSheet
        }
    }
    
    private var headerDateString: String {
        switch resolution {
        case .day:
            return currentStart.formatted(.dateTime.day().month().year())
        case .week:
            return "\(currentStart.formatted(.dateTime.day().month())) - \(currentEnd.formatted(.dateTime.day().month()))"
        case .month:
            return currentStart.formatted(.dateTime.month(.wide).year())
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
    }
    
    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Resolution") {
                    Picker("View By", selection: $resolution) {
                        ForEach(DetailResolution.allCases) { res in
                            Label(res.rawValue, systemImage: res.icon).tag(res)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: resolution) { _, _ in
                        updatePeriod(from: pickerDate)
                    }
                }
                
                Section("Jump to Date") {
                    DatePicker("Target Date", selection: $pickerDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .onChange(of: pickerDate) { _, newDate in
                            resolution = .day // Explicitly switch to 'Day' view when a date is selected
                            updatePeriod(from: newDate)
                        }
                }
            }
            .navigationTitle("Filter Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Apply") { isPeriodPickerPresented = false }
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func updatePeriod(from date: Date) {
        let calendar = Calendar.current
        switch resolution {
        case .day:
            currentStart = calendar.startOfDay(for: date)
            currentEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        case .week:
            currentStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            currentEnd = calendar.date(byAdding: .day, value: 6, to: currentStart)!
        case .month:
            currentStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            currentEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: currentStart)!
        }
    }
}
