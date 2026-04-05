import SwiftData
import SwiftUI

@main
struct PaymentTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            PaymentTrackerRoot()
        }
        .modelContainer(try! ModelContainer.appContainer())
    }
}
