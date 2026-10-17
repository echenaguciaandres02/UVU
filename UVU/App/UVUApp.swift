import SwiftUI
import SwiftData

@main
struct UVUApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Appearance.configure()
        _ = AppContainer.shared
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(\.locale, AppLocale.spanish)
                .preferredColorScheme(.dark)
                .tint(.bone)
                .background(Color.ink.ignoresSafeArea())
        }
        .modelContainer(AppContainer.shared)
        .onChange(of: scenePhase) { _, phase in
            // El journal protegido se vuelve a bloquear al salir de la app.
            if phase == .background {
                JournalLock.shared.lock()
            }
            // Si el descanso terminó con el teléfono bloqueado, cierra su Live Activity.
            if phase == .active {
                RestTimer.shared.refresh()
            }
        }
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

/// La base de datos única de la app. La usan las pantallas y también las acciones de las
/// notificaciones ("Completar" funciona aunque la app esté cerrada).
@MainActor
enum AppContainer {
    static let shared: ModelContainer = {
        #if DEBUG
        // Capturas automáticas: datos de ejemplo en memoria, sin tocar la base real.
        if LaunchOptions.demoData {
            let container = DataStore.makeContainer(inMemory: true)
            SeedData.seed(context: container.mainContext)
            DemoData.populate(context: container.mainContext)
            return container
        }
        #endif

        let container = DataStore.makeContainer()
        SeedData.seedIfNeeded(context: container.mainContext)
        if DataUpgrades.run(context: container.mainContext) {
            let context = container.mainContext
            Task { await NotificationService.rescheduleAll(context: context) }
        }
        return container
    }()
}

#if DEBUG
/// Argumentos de arranque que usan las pruebas de interfaz.
enum LaunchOptions {
    static var gallery: Bool { CommandLine.arguments.contains("-uvu-gallery") }
    static var demoData: Bool { CommandLine.arguments.contains("-uvu-demo-data") }
}
#endif
