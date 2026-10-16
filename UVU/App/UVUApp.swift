import SwiftUI
import SwiftData

@main
struct UVUApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    let container: ModelContainer

    init() {
        Appearance.configure()

        #if DEBUG
        // Capturas automáticas: datos de ejemplo en memoria, sin tocar la base real.
        if LaunchOptions.demoData {
            container = DataStore.makeContainer(inMemory: true)
            SeedData.seed(context: container.mainContext)
            DemoData.populate(context: container.mainContext)
            return
        }
        #endif

        container = DataStore.makeContainer()
        SeedData.seedIfNeeded(context: container.mainContext)
        if DataUpgrades.run(context: container.mainContext) {
            let context = container.mainContext
            Task { await NotificationService.rescheduleAll(context: context) }
        }
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(\.locale, AppLocale.spanish)
                .preferredColorScheme(.dark)
                .tint(.bone)
                .background(Color.ink.ignoresSafeArea())
        }
        .modelContainer(container)
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if LaunchOptions.gallery {
            DesignSystemGallery()
        } else {
            RootTabView()
        }
        #else
        RootTabView()
        #endif
    }
}

#if DEBUG
/// Argumentos de arranque que usan las pruebas de interfaz.
enum LaunchOptions {
    static var gallery: Bool { CommandLine.arguments.contains("-uvu-gallery") }
    static var demoData: Bool { CommandLine.arguments.contains("-uvu-demo-data") }
}
#endif
