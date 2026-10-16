import Foundation
import SwiftData

/// Versión 1 del esquema de datos. Cuando cambie un modelo de forma incompatible,
/// se crea `SchemaV2` y una etapa en `UVUMigrationPlan` para no perder datos.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Habit.self, HabitEntry.self,
            TaskList.self, TaskItem.self, Subtask.self,
            JournalEntry.self, PromptAnswer.self, JournalTag.self,
            Exercise.self, Routine.self, RoutineExercise.self,
            WorkoutSession.self, SessionExercise.self, WorkoutSet.self,
        ]
    }
}

enum UVUMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum DataStore {
    /// App Group compartido con los widgets (fase 7).
    static let appGroupID = "group.com.uvu.app"

    /// Contenedor de iCloud para cuando se active la sincronización.
    static let cloudKitContainerID = "iCloud.com.uvu.app"

    /// Si el App Group está disponible se usa su carpeta (para que los widgets lean
    /// los datos); si no, la carpeta normal de la app.
    static var storeURL: URL {
        let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "UVU.store")
    }

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else {
            // Para activar iCloud más adelante (requiere cuenta de Apple Developer):
            // cambiar `.none` por `.private(cloudKitContainerID)` y añadir la capacidad
            // iCloud + CloudKit al target en project.yml.
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        }

        do {
            return try ModelContainer(for: schema, migrationPlan: UVUMigrationPlan.self, configurations: configuration)
        } catch {
            fatalError("No se pudo abrir la base de datos: \(error)")
        }
    }
}
