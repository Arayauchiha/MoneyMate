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
        repeatFrequency: String = "never",
        linkedGoal: Goal? = nil
    ) {
        let isScheduled = date > Date()
        guard let context = modelContext else { return }
        let txn = Transaction(amount: amount, type: type, category: category, linkedGoal: linkedGoal, date: date, title: title, note: note, repeatFrequency: repeatFrequency, isScheduled: isScheduled)
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
        repeatFrequency: String = "never",
        linkedGoal: Goal? = nil
    ) {
        transaction.money = amount
        transaction.type = type
        transaction.category = category
        transaction.date = date
        transaction.title = title
        transaction.note = note
        transaction.repeatFrequency = repeatFrequency
        transaction.isScheduled = date > Date()
        transaction.linkedGoal = linkedGoal
        guard let context = modelContext else { return }
        save(context: context)
        Task { await load() }
    }

    @MainActor
    func archive(_ transaction: Transaction) {
        transaction.isArchived = true
        transaction.archivedDate = Date()
        guard let context = modelContext else { return }
        save(context: context)
        Task { @MainActor in
            await load()
        }
    }

    @MainActor
    func archiveMultiple(_ transactions: [Transaction]) {
        guard let context = modelContext else { return }
        let now = Date()
        for txn in transactions {
            txn.isArchived = true
            txn.archivedDate = now
        }
        save(context: context)
        Task { @MainActor in
            await load()
        }
    }

    @MainActor
    func restore(_ transaction: Transaction) {
        transaction.isArchived = false
        transaction.archivedDate = nil
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
            txn.archivedDate = nil
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
        let today = Date()
        let base = allTransactions.filter { !$0.isArchived }

        // Expand recurring transactions into all their occurrences up to today
        var expanded: [Transaction] = []
        for txn in base {
            if txn.repeatFrequency == "never" {
                txn.displayDate = nil  // ensure no stale display date
                expanded.append(txn)
            } else {
                let dates = txn.occurrenceDates(upTo: today)
                for (index, occurrenceDate) in dates.enumerated() {
                    if index == 0 {
                        // First occurrence — real stored date, use as-is
                        txn.displayDate = nil
                        expanded.append(txn)
                    } else {
                        // Virtual occurrence — stamp displayDate on a new in-memory clone
                        // We must NOT reuse the same reference with a different displayDate
                        // because it's a reference type. Use a fresh object with same id instead,
                        // but to keep modelContext valid, we clone via a helper on the model itself.
                        let clone = txn.virtualOccurrence(on: occurrenceDate)
                        expanded.append(clone)
                    }
                }
            }
        }

        var result = expanded

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

        filteredTransactions = result.sorted { $0.effectiveDate > $1.effectiveDate }
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

    @MainActor
    func cleanupOldArchives() {
        guard let context = modelContext else { return }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let toDelete = allTransactions.filter { txn in
            txn.isArchived && (txn.archivedDate ?? .distantPast) < thirtyDaysAgo
        }
        
        guard !toDelete.isEmpty else { return }
        
        for txn in toDelete {
            context.delete(txn)
        }
        save(context: context)
        Task { await load() }
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
