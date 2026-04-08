import SwiftUI
import SwiftData

struct AllCategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    @State private var currentStart: Date
    @State private var currentEnd: Date
    @State private var resolution: DetailResolution
    @State private var pickerDate: Date
    @State private var isPeriodPickerPresented = false
    
    init() {
        let calendar = Calendar.current
        let today = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        self._currentStart = State(initialValue: startOfMonth)
        self._currentEnd = State(initialValue: endOfMonth)
        self._pickerDate = State(initialValue: startOfMonth)
        self._resolution = State(initialValue: .month)
    }
    
    private var filteredTransactions: [Transaction] {
        transactions.filter { txn in
            txn.type == .expense &&
            txn.date >= currentStart &&
            txn.date <= currentEnd &&
            !txn.isArchived
        }
    }
    
    private var categoryTotals: [CategoryTotal] {
        let uncategorisedID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let grouped = Dictionary(grouping: filteredTransactions, by: { $0.category?.id ?? uncategorisedID })
        return grouped
            .map { _, txns -> CategoryTotal in
                let total = txns.reduce(Money.zero) { $0 + $1.money }
                let category = txns.first { $0.category != nil }?.category
                return CategoryTotal(category: category, total: total, transactionCount: txns.count)
            }
            .sorted { $0.total.amount > $1.total.amount }
    }
    
    var body: some View {
        List {
            Section {
                if categoryTotals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("No transactions found.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                } else {
                    ForEach(categoryTotals) { categoryTotal in
                        NavigationLink(destination: CategoryDetailView(category: categoryTotal.category, startDate: currentStart, endDate: currentEnd)) {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(categoryTotal.categoryColor.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        Image(systemName: categoryTotal.categoryIcon)
                                            .foregroundStyle(categoryTotal.categoryColor)
                                            .font(.headline)
                                    }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(categoryTotal.categoryName)
                                        .font(.headline)
                                    Text("\(categoryTotal.transactionCount) transactions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(categoryTotal.formattedTotal)
                                    .font(.headline).bold()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } header: {
                Text("Complete Breakdown")
            } footer: {
                Text("Period: \(currentStart.formatted(.dateTime.day().month())) - \(currentEnd.formatted(.dateTime.day().month().year()))")
            }
        }
        .navigationTitle("All Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPeriodPickerPresented = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                }
            }
        }
        .sheet(isPresented: $isPeriodPickerPresented) {
            filterSheet
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
                                updatePeriod(from: newDate)
                            }
                    }
                }
            }
            .navigationTitle("Filter Breakdown")
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
    }
}
