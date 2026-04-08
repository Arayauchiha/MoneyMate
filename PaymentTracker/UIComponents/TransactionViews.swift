import SwiftUI
import SwiftData

struct TransactionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppStateViewModel.self) private var appStateViewModel
    
    let transaction: Transaction
    var action: (() -> Void)? = nil
    @State private var isPressed = false
    
    var body: some View {
        guard transaction.modelContext != nil else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 16) {
                // Modern Fintech Icon with Gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(transaction.type == .expense ? FintechDesign.expenseGradient.opacity(0.15) : FintechDesign.incomeGradient.opacity(0.15))
                    
                    Image(systemName: transaction.type.systemImage)
                        .foregroundStyle(transaction.type == .expense ? FintechDesign.expenseGradient : FintechDesign.incomeGradient)
                        .font(.system(size: 18, weight: .bold))
                }
                .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.title.isEmpty ? (transaction.category?.name ?? "Miscellaneous") : transaction.title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(FintechDesign.adaptiveColor("1A1A1A", "FFFFFF"))
                    
                    if let category = transaction.category {
                        Text(category.name)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(category.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(category.color.opacity(0.1), in: Capsule())
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(transaction.formattedAmount)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(transaction.type == .expense ? FintechDesign.adaptiveColor("1A1A1A", "FFFFFF") : Color(hex: "10B981"))
                    
                    Text(transaction.date.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(FintechDesign.adaptiveColor("666666", "999999"))
                }
            }
            .padding(16)
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                FintechDesign.adaptiveColor("E0E0E0", "FFFFFF").opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .onTapGesture {
                action?()
            }
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isPressed = pressing
                }
            }, perform: {})
        )
    }
}

struct TransactionRow: View {
    @Environment(AppStateViewModel.self) private var appStateViewModel
    let transaction: Transaction
    
    var body: some View {
        guard transaction.modelContext != nil else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(transaction.type == .expense ? FintechDesign.expenseGradient.opacity(0.1) : FintechDesign.incomeGradient.opacity(0.1))
                    Image(systemName: transaction.type.systemImage)
                        .foregroundStyle(transaction.type == .expense ? FintechDesign.expenseGradient : FintechDesign.incomeGradient)
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.title.isEmpty ? (transaction.category?.name ?? "Miscellaneous") : transaction.title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(FintechDesign.adaptiveColor("1A1A1A", "FFFFFF"))
                    
                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(FintechDesign.adaptiveColor("666666", "999999"))
                }
                
                Spacer()
                
                Text(transaction.formattedAmount)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(transaction.type == .expense ? FintechDesign.adaptiveColor("1A1A1A", "FFFFFF") : Color(hex: "10B981"))
            }
            .padding(16)
            .contentShape(Rectangle())
        )
    }
}
