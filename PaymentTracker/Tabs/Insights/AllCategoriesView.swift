import SwiftUI

struct AllCategoriesView: View {
    let allTotals: [CategoryTotal]
    let dateRange: (start: Date, end: Date)
    
    var body: some View {
        List {
            Section {
                ForEach(allTotals) { categoryTotal in
                    NavigationLink(destination: CategoryDetailView(category: categoryTotal.category, startDate: dateRange.start, endDate: dateRange.end)) {
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
            } header: {
                Text("Complete Breakdown")
            } footer: {
                Text("Period: \(dateRange.start.formatted(.dateTime.day().month())) - \(dateRange.end.formatted(.dateTime.day().month().year()))")
            }
        }
        .navigationTitle("All Categories")
        .navigationBarTitleDisplayMode(.inline)
    }
}
