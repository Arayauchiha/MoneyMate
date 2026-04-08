import SwiftUI
import SwiftData

// MARK: - Smart Nudge Model
struct SmartNudge: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
}

// MARK: - Notification Centre View
struct NotificationCentreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStateViewModel.self) private var appStateViewModel

    @Query(sort: \AppNotification.date, order: .reverse)
    private var notifications: [AppNotification]

    @Query private var allTransactions: [Transaction]
    @Query private var allGoals: [Goal]

    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if notifications.isEmpty {
                        emptyState
                    } else {
                        notificationsList
                    }

                    // Smart nudges always shown at bottom
                    if !smartNudges.isEmpty {
                        nudgesSection
                    }
                }
                .padding()
            }
            .background(FintechDesign.Background())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }

                if !notifications.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Text("Clear All")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .confirmationDialog("Clear all notifications?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    clearAll()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .onAppear {
                markAllRead()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.blue.opacity(0.5))
            }

            VStack(spacing: 6) {
                Text("No Notifications Yet")
                    .font(.title3.bold())
                    .foregroundStyle(FintechDesign.primaryText)

                Text("You're all caught up! But here's something you might find interesting...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(24)
        .background(
            FintechDesign.CardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Unread count badge
            let unread = notifications.filter { !$0.isRead }.count
            if unread > 0 {
                HStack {
                    Text("\(unread) unread")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                    Spacer()
                }
                .padding(.bottom, 12)
            }

            VStack(spacing: 1) {
                ForEach(notifications) { notif in
                    notifRow(notif)
                }
            }
            .background(
                FintechDesign.CardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            )
        }
    }

    @ViewBuilder
    private func notifRow(_ notif: AppNotification) -> some View {
        HStack(spacing: 14) {
            // Icon circle
            Circle()
                .fill(Color(hex: notif.type.color).opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: notif.type.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: notif.type.color))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(notif.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(FintechDesign.primaryText)
                Text(notif.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(notif.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !notif.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(notif.isRead ? Color.clear : Color.blue.opacity(0.03))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(notif)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Smart Nudges

    private var nudgesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("💡 You Might Find This Interesting")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ForEach(smartNudges) { nudge in
                nudgeCard(nudge)
            }
        }
    }

    private func nudgeCard(_ nudge: SmartNudge) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(nudge.iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: nudge.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(nudge.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(nudge.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(FintechDesign.primaryText)
                Text(nudge.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(16)
        .background(
            FintechDesign.CardBackground()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(nudge.iconColor.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Smart Nudges Engine

    private var smartNudges: [SmartNudge] {
        var nudges: [SmartNudge] = []
        let calendar = Calendar.current
        let expenses = allTransactions.filter { !$0.isArchived && $0.type == .expense }

        // 1. Days since last transaction
        if let lastDate = expenses.sorted(by: { $0.date > $1.date }).first?.date {
            let days = calendar.dateComponents([.day], from: lastDate, to: .now).day ?? 0
            if days >= 2 {
                nudges.append(SmartNudge(
                    icon: "clock.fill",
                    iconColor: .orange,
                    title: "No Recent Logs",
                    body: "You haven't logged a transaction in \(days) day\(days == 1 ? "" : "s"). Keeping your logs up to date gives you better insights."
                ))
            }
        }

        // 2. Weekend vs Weekday spend
        let weekdayTxns = expenses.filter { !calendar.isDateInWeekend($0.date) }
        let weekendTxns = expenses.filter { calendar.isDateInWeekend($0.date) }
        let weekdayDays = max(1, Set(weekdayTxns.map { calendar.startOfDay(for: $0.date) }).count)
        let weekendDays = max(1, Set(weekendTxns.map { calendar.startOfDay(for: $0.date) }).count)
        let weekdayAvg = weekdayTxns.reduce(Decimal(0)) { $0 + $1.money.amount } / Decimal(weekdayDays)
        let weekendAvg = weekendTxns.reduce(Decimal(0)) { $0 + $1.money.amount } / Decimal(weekendDays)

        if weekendAvg > weekdayAvg * 1.5 && weekendDays > 1 {
            let ratio = Int((((weekendAvg / weekdayAvg) - 1) * 100 as NSDecimalNumber).doubleValue)
            nudges.append(SmartNudge(
                icon: "sun.max.fill",
                iconColor: .yellow,
                title: "Weekend Spender",
                body: "You spend ~\(ratio)% more on weekends than weekdays. Consider setting a weekend budget."
            ))
        }

        // 3. Top category this month
        let thisMonth = expenses.filter {
            calendar.isDate($0.date, equalTo: .now, toGranularity: .month)
        }
        if !thisMonth.isEmpty {
            let grouped = Dictionary(grouping: thisMonth) { $0.category?.name ?? "Misc" }
            if let topCat = grouped.max(by: { a, b in
                a.value.reduce(Decimal(0)) { $0 + $1.money.amount } <
                b.value.reduce(Decimal(0)) { $0 + $1.money.amount }
            }) {
                let total = topCat.value.reduce(Decimal(0)) { $0 + $1.money.amount }
                nudges.append(SmartNudge(
                    icon: "chart.pie.fill",
                    iconColor: .purple,
                    title: "Top Category This Month",
                    body: "\(topCat.key) is your biggest expense this month at \(Money(total).formatted(with: appStateViewModel.userCurrency))."
                ))
            }
        }

        // 4. Goal near completion
        for goal in allGoals {
            let currentAmount = goal.transactions?
                .filter { !$0.isArchived }
                .reduce(Decimal(0)) { $0 + $1.money.amount } ?? 0
            let currentMoney = Money(currentAmount)
            let status = goal.status(currentAmount: currentMoney)
            let progress = goal.progress(currentAmount: currentMoney)
            
            if status != .achieved {
                if progress >= 0.8 && progress < 1.0 {
                    let remaining = Int((1.0 - progress) * 100)
                    nudges.append(SmartNudge(
                        icon: "target",
                        iconColor: .green,
                        title: "Goal Almost There!",
                        body: "You're \(remaining)% away from completing \"\(goal.title)\". Keep it up!"
                    ))
                }
            }
        }

        // 5. Good saving streak
        let last7Days = expenses.filter {
            let diff = calendar.dateComponents([.day], from: $0.date, to: .now).day ?? 99
            return diff <= 7
        }
        if last7Days.isEmpty {
            nudges.append(SmartNudge(
                icon: "star.fill",
                iconColor: .green,
                title: "Zero Spend Week 🎉",
                body: "You haven't logged any expenses in the last 7 days. That's impressive!"
            ))
        }

        return Array(nudges.prefix(3)) // Max 3 nudges
    }

    // MARK: - Actions

    private func markAllRead() {
        for notif in notifications where !notif.isRead {
            notif.isRead = true
        }
        try? modelContext.save()
    }

    private func clearAll() {
        for notif in notifications {
            modelContext.delete(notif)
        }
        try? modelContext.save()
    }
}
