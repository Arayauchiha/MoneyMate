import SwiftUI
import UIKit

enum FintechDesign {
    // MARK: - Colors (Adaptive Semantic)
    struct Background: View {
        var body: some View {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
        }
    }
    
    struct CardBackground: View {
        var body: some View {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
    
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    
    static func adaptiveColor(_ light: String, _ dark: String) -> Color {
        Color(UIColor { traitCollection in
            return UIColor(hex: traitCollection.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // MARK: - Gradients
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "06B6D4"), Color(hex: "10B981")], // Teal to Green
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let expenseGradient = LinearGradient(
        colors: [Color(hex: "FF512F"), Color(hex: "DD2476")], // Red to Pink
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let incomeGradient = LinearGradient(
        colors: [Color(hex: "11998E"), Color(hex: "38EF7D")], // Emerald to Lime
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Components
    struct WalletCard: View {
        @Environment(\.colorScheme) private var colorScheme
        let balance: String
        let safeToSpend: String
        let income: String
        let expenses: String
        let goals: String
        let cardHolder: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Header Row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MoneyMate")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.heavy)
                        Text("Active Wallet")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                }
                .foregroundStyle(.white)
                .padding(.bottom, 14) // Reduced gap
                
                // Main Balance
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Balance")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                    
                    Text(balance)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                }
                .padding(.bottom, 8) // Reduced gap
                
                // Safe to Spend Section (Redesigned)
                if safeToSpend != "0" {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Safe to Spend")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "leaf.fill")
                                .font(.caption)
                            Text(safeToSpend)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(.bottom, 14) // Reduced gap
                } else {
                    Spacer(minLength: 14)
                }
                
                Spacer()
                
                // Stats Footer (Left Aligned Style)
                HStack(spacing: 24) {
                    StatItem(title: "Income", value: income, icon: "arrow.down")
                    StatItem(title: "Goals", value: goals, icon: "target")
                    StatItem(title: "Spent", value: expenses, icon: "arrow.up")
                }
            }
            .padding(32) // Increased outer padding
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .background(
                FintechDesign.brandGradient
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 200, height: 200)
                                .offset(x: 150, y: -80)
                            
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 150, height: 150)
                                .offset(x: -120, y: 100)
                        }
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            // Removed heavy static shadow for a cleaner look
        }
    }
    
    private struct StatItem: View {
        let title: String
        let value: String
        let icon: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .black))
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white.opacity(0.6))
                
                Text(value)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}
