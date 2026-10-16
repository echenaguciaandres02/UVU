import SwiftUI
import SwiftData

@main
struct UVUApp: App {
    let container: ModelContainer

    init() {
        container = DataStore.makeContainer()
        SeedData.seedIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.locale, AppLocale.spanish)
        }
        .modelContainer(container)
    }
}
