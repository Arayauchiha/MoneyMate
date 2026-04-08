import SwiftUI
import SwiftData
import Charts

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
    let isDateSummary: Bool
    
    @State private var currentStart: Date
    @State private var currentEnd: Date
    @State private var resolution: DetailResolution
    @State private var pickerDate: Date // Independent state for the picker to prevent auto-snapping to 1st
    
    @State private var isPeriodPickerPresented = false
    
    @Query private var transactions: [Transaction]
    
    init(category: Category?, startDate: Date, endDate: Date, isDateSummary: Bool = false) {
        self.category = category
        self.isDateSummary = isDateSummary
        self._currentStart = State(initialValue: startDate)
        self._currentEnd = State(initialValue: endDate)
        self._pickerDate = State(initialValue: startDate)
        
        let components = Calendar.current.dateComponents([.day], from: startDate, to: endDate)
        let days = components.day ?? 1
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
            (isDateSummary ? true : (category == nil ? txn.category == nil : txn.category?.id == category?.id))
        }
    }
    
    @Environment(AppStateViewModel.self) private var appStateViewModel
    @State private var isChartAnimated = false

    private var chartData: [DailyTotal] {
        let calendar = Calendar.current
        let range = calendar.dateComponents([.day], from: currentStart, to: currentEnd).day ?? 1
        let iterations = max(1, range + 1)
        
        return (0..<iterations).map { offset -> DailyTotal in
            let date = calendar.date(byAdding: .day, value: offset, to: currentStart)!
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            
            let total = filteredTransactions
                .filter { $0.date >= start && $0.date < end }
                .reduce(Money.zero) { $0 + $1.money }
            
            return DailyTotal(date: date, total: total)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Hero Header
                VStack(spacing: 24) {
                    HStack(spacing: 20) {
                        Circle()
                            .fill((isDateSummary ? .blue : (category?.color ?? .gray)).gradient)
                            .frame(width: 64, height: 64)
                            .overlay {
                                Image(systemName: isDateSummary ? resolution.icon : (category?.iconName ?? "questionmark.circle"))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isDateSummary ? (resolution == .month ? "Monthly Summary" : resolution == .week ? "Weekly Summary" : "Daily Summary") : (category?.name ?? "Other"))
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundStyle(FintechDesign.primaryText)
                            
                            Button {
                                isPeriodPickerPresented = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                    Text(headerDateString)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.1), in: Capsule())
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Spend")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(Money(filteredTransactions.reduce(0) { $0 + $1.money.amount }).formatted(with: appStateViewModel.userCurrency))
                                .font(.title3.bold())
                                .foregroundStyle(FintechDesign.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(FintechDesign.adaptiveColor("F5F5F7", "FFFFFF").opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transactions")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            let count = filteredTransactions.count
                            Text("\(count) \(count == 1 ? "Transaction" : "Transactions")")
                                .font(.title3.bold())
                                .foregroundStyle(FintechDesign.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(FintechDesign.adaptiveColor("F5F5F7", "FFFFFF").opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                .padding(24)
                .background(
                    FintechDesign.CardBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                )
                
                // MARK: - Trend Analysis
                VStack(alignment: .leading, spacing: 20) {
                    Text("Spending Trend")
                        .font(.headline)
                        .foregroundStyle(FintechDesign.primaryText)
                    
                    Chart {
                        ForEach(chartData) { data in
                            BarMark(
                                x: .value("Day", data.dayLabel),
                                y: .value("Amount", isChartAnimated ? data.total.amount : 0)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        (isDateSummary ? .blue : (category?.color ?? .blue)),
                                        (isDateSummary ? .blue : (category?.color ?? .blue)).opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(6)
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine()
                                .foregroundStyle(Color.gray.opacity(0.1))
                            AxisValueLabel()
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.gray)
                        }
                    }
                    .tint(Color.gray)
                    .chartYScale(domain: 0...(chartData.map { $0.total.amount }.max() ?? 100))
                    .frame(height: 180)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isChartAnimated)
                }
                .padding(24)
                .background(
                    FintechDesign.CardBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                )
                .onAppear {
                    isChartAnimated = false
                    withAnimation(.easeInOut(duration: 0.8).delay(0.1)) {
                        isChartAnimated = true
                    }
                }
                .onChange(of: currentStart) { _, _ in
                    isChartAnimated = false
                    withAnimation(.easeInOut(duration: 0.8)) {
                        isChartAnimated = true
                    }
                }

                // MARK: - Activity Log
                VStack(alignment: .leading, spacing: 16) {
                    Text("Activity History")
                        .font(.headline)
                        .foregroundStyle(FintechDesign.primaryText)
                    
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
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredTransactions) { txn in
                                TransactionCard(transaction: txn) {
                                    transactionViewModel.presentEdit(txn)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
        .navigationTitle(isDateSummary ? "Spending Breakdown" : (category?.name ?? "Other"))
        .navigationBarTitleDisplayMode(.inline)
        .background(FintechDesign.Background())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPeriodPickerPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(4)
                }
            }
        }
        .sheet(isPresented: $isPeriodPickerPresented) {
            filterSheet
        }
    }
    
    private var headerDateString: String {
        let calendar = Calendar.current
        switch resolution {
        case .day:
            return currentStart.formatted(.dateTime.day().month().year())
        case .week:
            let week = calendar.component(.weekOfYear, from: currentStart)
            return "Week \(week) (\(currentStart.formatted(.dateTime.day().month())) - \(currentEnd.formatted(.dateTime.day().month())))"
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
                    .fontWeight(.black)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(color.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(color.opacity(0.15), lineWidth: 1)
                }
        }
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
                    VStack(alignment: .leading, spacing: 8) {
                        if resolution == .week {
                            let week = Calendar.current.component(.weekOfYear, from: pickerDate)
                            Text("Selecting Week \(week)")
                                .font(.caption).bold()
                                .foregroundStyle(.blue)
                        }
                        
                        DatePicker("Target Date", selection: $pickerDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .onChange(of: pickerDate) { _, newDate in
                                // Keep the resolution user selected, just update the window
                                updatePeriod(from: newDate)
                            }
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
        isChartAnimated = false // Reset animation
        let calendar = Calendar.current
        switch resolution {
        case .day:
            currentStart = calendar.startOfDay(for: date)
            currentEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        case .week:
            var current = calendar.startOfDay(for: date)
            while calendar.component(.weekday, from: current) != 2 {
                current = calendar.date(byAdding: .day, value: -1, to: current)!
            }
            currentStart = current
            currentEnd = calendar.date(byAdding: .day, value: 6, to: currentStart)!
        case .month:
            currentStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            currentEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: currentStart)!
        }
        
        withAnimation(.easeInOut(duration: 0.8)) {
            isChartAnimated = true
        }
    }
}
