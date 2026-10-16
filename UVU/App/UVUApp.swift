import SwiftUI
import SwiftData

@main
struct UVUApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        container = DataStore.makeContainer()
        SeedData.seedIfNeeded(context: container.mainContext)
        DataUpgrades.run(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.locale, AppLocale.spanish)
        }
        .modelContainer(container)
    }
}
