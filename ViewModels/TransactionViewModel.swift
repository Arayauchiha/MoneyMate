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
        title: String,
        note: String,
        linkedGoal: Goal? = nil
    ) {
        guard let context = modelContext else { return }
        let txn = Transaction(amount: amount, type: type, category: category, linkedGoal: linkedGoal, date: date, title: title, note: note)
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
        title: String,
        note: String,
        linkedGoal: Goal? = nil
    ) {
        transaction.money = amount
        transaction.type = type
        transaction.category = category
        transaction.date = date
        transaction.title = title
        transaction.note = note
        transaction.linkedGoal = linkedGoal
        guard let context = modelContext else { return }
        save(context: context)
        Task { await load() }
    }

    @MainActor
    func archive(_ transaction: Transaction) {
        transaction.isArchived = true
        guard let context = modelContext else { return }
        save(context: context)
        Task { @MainActor in
            await load()
        }
    }

    @MainActor
    func archiveMultiple(_ transactions: [Transaction]) {
        guard let context = modelContext else { return }
        for txn in transactions {
            txn.isArchived = true
        }
        save(context: context)
        Task { @MainActor in
            await load()
        }
    }

    @MainActor
    func restore(_ transaction: Transaction) {
        transaction.isArchived = false
        guard let context = modelContext else { return }
        save(context: context)
        Task { @MainActor in
            await load()
        }
    }

    @MainActor
    func restoreMultiple(_ transactions: [Transaction]) {
        guard let context = modelContext else { return }
        for txn in transactions {
            txn.isArchived = false
        }
        save(context: context)
        Task { @MainActor in
            await load()
        }
    }

    @MainActor
    func deletePermanently(_ transaction: Transaction) {
        guard let context = modelContext else { return }
        // Remove from local arrays first to prevent UI access during deletion
        allTransactions.removeAll { $0.id == transaction.id }
        applyFilters()
        
        context.delete(transaction)
        save(context: context)
        Task { @MainActor in
            await load()
        }
    }

    @MainActor
    func deleteMultiplePermanently(_ transactions: [Transaction]) {
        guard let context = modelContext else { return }
        let ids = Set(transactions.map { $0.id })
        allTransactions.removeAll { ids.contains($0.id) }
        applyFilters()

        for txn in transactions {
            context.delete(txn)
        }
        save(context: context)
        Task { @MainActor in
            await load()
        }
    }

    @MainActor
    func archive(at offsets: IndexSet) {
        let targets = offsets.map { filteredTransactions[$0] }
        targets.forEach { archive($0) }
    }

    func applyFilters() {
        var result = allTransactions

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
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

        result = result.filter { !$0.isArchived }
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
