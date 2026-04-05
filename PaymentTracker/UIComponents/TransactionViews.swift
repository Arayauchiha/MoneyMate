import SwiftUI

struct TransactionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let transaction: Transaction
    var action: (() -> Void)? = nil
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(transaction.type.color.gradient)
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: transaction.type.systemImage)
                        .foregroundStyle(.white)
                        .font(.headline)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                if transaction.type == .transfer, let goal = transaction.linkedGoal {
                    Text("Funded: \(goal.title)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                } else {
                    Text(transaction.note.isEmpty ? transaction.category?.name ?? transaction.type.label : transaction.note)
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
                        .foregroundStyle(colorScheme == .light ? tagColor.opacity(0.9) : tagColor)
                        .colorMultiply(colorScheme == .light ? Color(white: 0.6) : .white)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.formattedAmount)
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
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(transaction.type.color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: transaction.type.systemImage)
                        .foregroundStyle(transaction.type.color)
                        .font(.title3)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                if transaction.type == .transfer, let goal = transaction.linkedGoal {
                    Text("Funded: \(goal.title)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                } else {
                    Text(transaction.note.isEmpty ? transaction.category?.name ?? transaction.type.label : transaction.note)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(transaction.formattedAmount)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(transaction.type.color)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
