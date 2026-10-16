import SwiftData

/// Base de datos en memoria con los datos iniciales, para las vistas previas de Xcode.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = DataStore.makeContainer(inMemory: true)
        SeedData.seed(context: container.mainContext)
        return container
    }()
}
