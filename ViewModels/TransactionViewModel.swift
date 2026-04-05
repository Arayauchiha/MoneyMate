import SwiftData
import SwiftUI

@Observable
final class TransactionViewModel {
    var allTransactions: [Transaction] = []
    var filteredTransactions: [Transaction] = []

    var searchQuery: String = "" {
        didSet { applyFilters() }
    }
    
    var dataVersion: Int = 0

    var selectedType: TransactionType? {
        didSet { applyFilters() }
    }

    var selectedCategory: Category? {
        didSet { applyFilters() }
    }

    var dateFrom: Date? {
        didSet { applyFilters() }
    }

    var dateTo: Date? {
        didSet { applyFilters() }
    }

    var isFilterSheetPresented: Bool = false
    var transactionToEdit: Transaction?
    var isAddEditSheetPresented: Bool = false

    var isLoading: Bool = false
    var error: String?

    var activeFilterCount: Int {
        [selectedType != nil,
         selectedCategory != nil,
         dateFrom != nil,
         dateTo != nil].filter(\.self).count
    }

    private var modelContext: ModelContext?

    func configure(context: ModelContext) {
        modelContext = context
        Task { await load() }
    }

    @MainActor
    func load() async {
        guard let context = modelContext else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let descriptor = FetchDescriptor<Transaction>(
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            allTransactions = try context.fetch(descriptor)
            applyFilters()
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func add(
        amount: Money,
        type: TransactionType,
        category: Category?,
        date: Date,
        note: String,
        linkedGoal: Goal? = nil
    ) {
        guard let context = modelContext else { return }
        let txn = Transaction(amount: amount, type: type, category: category, linkedGoal: linkedGoal, date: date, note: note)
        context.insert(txn)
        save(context: context)
        Task { await load() }
    }

    @MainActor
    func update(
        transaction: Transaction,
        amount: Money,
        type: TransactionType,
        category: Category?,
        date: Date,
        note: String,
        linkedGoal: Goal? = nil
    ) {
        transaction.money = amount
        transaction.type = type
        transaction.category = category
        transaction.date = date
        transaction.note = note
        transaction.linkedGoal = linkedGoal
        guard let context = modelContext else { return }
        save(context: context)
        Task { await load() }
    }

    @MainActor
    func delete(_ transaction: Transaction) {
        guard let context = modelContext else { return }
        context.delete(transaction)
        save(context: context)
        Task { await load() }
    }

    @MainActor
    func delete(at offsets: IndexSet) {
        let targets = offsets.map { filteredTransactions[$0] }
        targets.forEach { delete($0) }
    }

    func applyFilters() {
        var result = allTransactions

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.note.lowercased().contains(q) ||
                    ($0.category?.name.lowercased().contains(q) ?? false) ||
                    $0.money.formatted.contains(q)
            }
        }

        if let type = selectedType {
            result = result.filter { $0.type == type }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category?.id == category.id }
        }

        if let from = dateFrom {
            result = result.filter { $0.date >= from }
        }

        if let to = dateTo {
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: to)!
            result = result.filter { $0.date < endOfDay }
        }

        filteredTransactions = result
    }

    func clearFilters() {
        selectedType = nil
        selectedCategory = nil
        dateFrom = nil
        dateTo = nil
        searchQuery = ""
    }

    func presentAdd() {
        transactionToEdit = nil
        isAddEditSheetPresented = true
    }

    func presentEdit(_ transaction: Transaction) {
        transactionToEdit = transaction
        isAddEditSheetPresented = true
    }

    private func save(context: ModelContext) {
        do {
            try context.save()
            dataVersion += 1
        } catch {
            self.error = error.localizedDescription
        }
    }
}
