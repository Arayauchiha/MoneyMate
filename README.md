# MoneyMate — Personal Finance Companion

MoneyMate is a lightweight, intuitive personal finance tracker designed for daily use. Unlike complex banking applications, MoneyMate focuses on understanding money habits through clear visual trends, simple tracking, and robust data integrity.

## 🚀 Key Features

- **Dynamic Home Dashboard:** Instant visibility of total balance, income, and expenses with a weekly spending trend chart.
- **Smart Transaction Tracking:** Full management of financial entries with advanced search, category-based filtering, and date grouping.
- **Goal-Oriented Saving:** A dedicated goals system that calculates exactly what is "Available to Save," dynamically reacting to your real-world spending.
- **Insights & Audit Vault:** Detailed breakdowns of spending habits and a unique **Archive System** that preserves your financial history for audit purposes while keeping the main list clean.
- **Privacy & Security:** Native biometric protection with **Face ID** and a secure session locking mechanism.
- **Data Mobility:** Export your entire financial history to a standard CSV format for use in desktop tools like Excel or Numbers.

## 🏗️ Architecture & Engineering

MoneyMate is built using a modern, scalable stack:
- **SwiftUI:** For a truly native, fluid, and responsive user experience.
- **SwiftData:** Leveraging the latest persistence framework to ensure fast, offline-first data handling.
- **MVVM Patterns:** A clean separation of concerns between reactive ViewModels and localized UI components.
- **Responsive State Management:** Unified state handling via `@Observable` for consistent app-wide updates.

## 💡 Product Thinking

- **Data Integrity (The Archive Philosophy):** We chose to decouple "Soft Deletion" (Archiving) from "Hard Deletion." This ensures that a user's shown balance always matches their real-bank history, even if they want a clean transaction list.
- **Engagement (Goal Integration):** The "Goals" feature isn't just a static progress bar; it directly listens to your daily spending habits to give you a realistic "Safe to Save" amount.
- **Accessibility:** High-contrast SF Symbols, standard system spacing, and support for Dynamic Type ensure the app feels like a first-party Apple tool.

---
*Built as a submission for the Personal Finance Companion Mobile App assignment.*
