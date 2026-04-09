import SwiftUI

struct UserManualView: View {
    var body: some View {
        List {
            Section {
                ManualRow(
                    title: "Dashboard Overview",
                    icon: "house.fill",
                    color: .blue,
                    description: "Your home base. See your current balance, 'Available to Save' budget, and recent activity at a glance. Insights at the bottom provide high-level monthly trends."
                )

                ManualRow(
                    title: "Transactions Hub",
                    icon: "list.bullet.rectangle.fill",
                    color: .orange,
                    description: "Press '+' to log a spend, income, or transfer. Long-press any transaction to Archive it. Searching and filtering help you find historical data in seconds."
                )
            } header: {
                Text("Fundamentals")
            }

            Section {
                ManualRow(
                    title: "Savings Goals",
                    icon: "heart.fill",
                    color: .pink,
                    description: "Set a target amount and manual fund it over time. Transfers to these goals are safely deducted from your 'Available to Save' balance."
                )

                ManualRow(
                    title: "Budget Caps",
                    icon: "chart.bar.xaxis",
                    color: .red,
                    description: "Set limits on specific categories (e.g., Dining). MoneyMate automatically tracks expenses against these caps; no manual funding needed!"
                )

                ManualRow(
                    title: "No-Spend Challenges",
                    icon: "flame.fill",
                    color: .orange,
                    description: "Challenge yourself to avoid certain spend types. The app tracks your success streak automatically as you go about your month."
                )
            } header: {
                Text("Goal Tracking")
            }

            Section {
                ManualRow(
                    title: "Insights & Trends",
                    icon: "chart.pie.fill",
                    color: .purple,
                    description: "The Insights tab breaks down your spending by category. Tap on a category to see its historical trend and associated transactions."
                )

                ManualRow(
                    title: "Archive Vault",
                    icon: "archivebox.fill",
                    color: .secondary,
                    description: "Archived transactions stay for historical completeness but won't clutter your main list. Access them via the vault icon in the Transactions tab."
                )
            } header: {
                Text("Data & Analysis")
            }

            Section {
                ManualRow(
                    title: "Security & Export",
                    icon: "lock.shield.fill",
                    color: .green,
                    description: "Enable Face ID in Settings for automatic lock when leaving the app. Use the CSV export to get your data—including Date and Time—into Excel."
                )
            } header: {
                Text("Settings")
            }
        }
        .navigationTitle("User Manual")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ManualRow: View {
    let title: String
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.12))
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.headline)
                }
                .frame(width: 40, height: 40)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.leading, 52)
        }
        .padding(.vertical, 8)
    }
}
