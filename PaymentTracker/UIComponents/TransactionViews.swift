import SwiftUI
import SwiftData

struct TransactionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppStateViewModel.self) private var appStateViewModel
    
    let transaction: Transaction
    var action: (() -> Void)? = nil
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Modern Glassmorphic Icon
            ZStack {
                Circle()
                    .fill(transaction.type.color.opacity(0.12))
                
                Circle()
                    .stroke(transaction.type.color.opacity(0.1), lineWidth: 1.5)
                
                Image(systemName: transaction.type.systemImage)
                    .foregroundStyle(transaction.type.color.gradient)
                    .font(.system(size: 18, weight: .bold))
            }
            .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                if transaction.type == .transfer, let goal = transaction.linkedGoal {
                    Text("Funded: \(goal.title)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } else {
                    Text(transaction.title.trimmingCharacters(in: .whitespaces).isEmpty ? (transaction.category?.name ?? "Miscellaneous") : transaction.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                if let category = transaction.category {
                    let tagColor = category.color
                    Text(category.name)
                        .font(.caption2)
                        .fontWeight(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tagColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(tagColor)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(appStateViewModel.userCurrency)\(transaction.money.formattedPlain)")
                    .font(.headline)
                    .bold()
                    .foregroundStyle(transaction.type == .expense ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.green))
                Text(transaction.date.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(isPressed ? 0.01 : 0.03), radius: isPressed ? 2 : 10, x: 0, y: isPressed ? 1 : 5)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .onTapGesture {
            action?()
        }
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct TransactionRow: View {
    @Environment(AppStateViewModel.self) private var appStateViewModel
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(transaction.type.color.opacity(0.1))
                Image(systemName: transaction.type.systemImage)
                    .foregroundStyle(transaction.type.color)
                    .font(.title3)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                if transaction.type == .transfer, let goal = transaction.linkedGoal {
                    Text("Funded: \(goal.title)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                } else {
                    Text(transaction.title.trimmingCharacters(in: .whitespaces).isEmpty ? (transaction.category?.name ?? "Miscellaneous") : transaction.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("\(appStateViewModel.userCurrency)\(transaction.money.formattedPlain)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(transaction.type.color)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
