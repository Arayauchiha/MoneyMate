# MoneyMate — Your Personal Finance Companion

MoneyMate is a high-performance, natively-built personal finance tracker designed for precision, daily habit tracking, and data integrity. Unlike generic banking apps, MoneyMate provides a deep analytical dive into your spending habits through a sophisticated "Insights" dashboard and a logic-driven "Goal" system.

## 🚀 Key Features

### 📊 Professional Insights & Trends
- **Interactive Dashboards:** Visualise financial health with donut charts, line graphs, and area charts powered by Swift Charts.
- **Deep Historical Analysis:** Filter data by Week, Month, Quarter, or Year, with the ability to drill down into any historical month from the last year.
- **Daily Performance:** Track "Average Spending per Day" to maintain daily budget discipline.

### 🎯 Proactive Goal System & Gamification
- **Multi-Type Goals:** Set targets for Savings, Budget Caps, No-Spend challenges, and Daily Limits.
- **Gamified Progress:** Track success through "Current" and "Longest" streaks for habit-based goals.
- **Goal Indicators:** Proactive status labels (On Track, At Risk, Achieved, Failed) that adapt dynamically to the remaining time and current spending velocity.

### 🛡️ Data Integrity (The Audit Philosophy)
- **Soft-Delete Archive:** Moves transactions to a secure "Audit Vault" instead of immediate deletion. This ensures your shown balance always matches your bank history while keeping your primary transaction list clean.
- **Bulk Audit Management:** Restore or permanently delete multiple transactions with full data safety warnings.

### 🔐 Security & Privacy
- **Native Biometrics:** Integrated Face ID and Passcode protection for the entire app.
- **Session Locking:** Automated session management that locks data when the app moves to the background.

### 🔔 Smart Notification Centre
- **Threshold Alerts:** Receive proactive notifications when you reach 80% of a budget cap or 90% of a saving goal.
- **Daily Reminders:** Configurable check-in reminders to keep your financial records up to date.

### 📂 Portability
- **CSV Export:** Instant export of all transactions into a standard CSV format for use in spreadsheet tools like Excel, Numbers, or Google Sheets.

## 🏗️ Technical Architecture

MoneyMate is built with a focus on scalability and performance:

- **SwiftUI + Observation:** Clean, reactive UI state management using the modern `@Observable` macro.
- **SwiftData Persistence:** High-performance, local-first data storage with efficient FetchDescriptors and Predicates.
- **MVVM-C Pattern:** Clear separation between models, views, and complex business logic in ViewModels.
- **Custom Design System:** The `FintechDesign` system provides adaptive tokens for Light/Dark modes, consistent typography (SF Rounded), and professional gradients.
- **Precision Accounting:** Uses a dedicated `Money` struct for all currency calculations to prevent floating-point errors.

## 🛠️ Requirements
- **iOS 17.0+** (Required for SwiftData and latest SwiftUI features)
- **Xcode 15.0+**
- **Swift 5.9+**

---
*Built with precision for the modern personal finance enthusiast.*
