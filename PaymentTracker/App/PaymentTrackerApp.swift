import SwiftData
import SwiftUI

@main
struct MoneyMateApp: App {
    var body: some Scene {
        WindowGroup {
            MoneyMateRoot()
        }
        .modelContainer(try! ModelContainer.appContainer())
    }
}
