import SwiftUI
import SwiftData
import Foundation

struct SpendingCategoryItem: Identifiable {
    let id = UUID()
    let category: Category?
    let amount: Money
    let transactionCount: Int
}

struct SpendingCategoryList: View {
    let categories: [SpendingCategoryItem]
    let appStateViewModel: AppStateViewModel
    
    // Optional dates to control drill-down range. Defaults to current week if nil.
    var startDate: Date? = nil
    var endDate: Date? = nil

    private var effectiveStart: Date {
        if let startDate { return startDate }
        let calendar = Calendar.current
        var date = calendar.startOfDay(for: Date())
        while calendar.component(.weekday, from: date) != 2 {
            date = calendar.date(byAdding: .day, value: -1, to: date)!
        }
        return date
    }

    private var effectiveEnd: Date {
        if let endDate { return endDate }
        return Calendar.current.date(byAdding: .day, value: 6, to: effectiveStart)!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, item in
                categoryRow(item: item, index: index)
            }
        }
    }

    @ViewBuilder
    private func categoryRow(item: SpendingCategoryItem, index: Int) -> some View {
        NavigationLink {
            CategoryDetailView(category: item.category, startDate: effectiveStart, endDate: effectiveEnd)
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill((item.category?.color ?? .gray).opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: item.category?.iconName ?? "questionmark.circle")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(item.category?.color ?? .gray)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.category?.name ?? "Miscellaneous")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(FintechDesign.primaryText)
                    Text("\(item.transactionCount) transactions")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.amount.formatted(with: appStateViewModel.userCurrency))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(FintechDesign.primaryText)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if index < categories.count - 1 {
            Divider()
                .padding(.leading, 80)
                .padding(.trailing, 24)
        }
    }
}
