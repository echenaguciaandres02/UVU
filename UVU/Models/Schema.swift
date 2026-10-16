import Foundation
import SwiftData

/// Modelos de la base de datos.
///
/// Cambios aditivos (propiedades nuevas con valor por defecto, modelos nuevos) los migra
/// SwiftData automáticamente sin perder datos, y `MigrationTests` lo comprueba con una base
/// creada por la versión anterior. Para cambios incompatibles (renombrar o cambiar el tipo
/// de una propiedad) hará falta un `SchemaMigrationPlan` con etapas.
///
/// Historial:
/// - Fase 1: esquema inicial.
/// - Fase 2b: `Habit.reminderMinutes` (varios recordatorios por hábito).
enum AppSchema {
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

enum DataStore {
    /// App Group compartido con los widgets (fase 7).
    static let appGroupID = "group.com.uvu.app"

    /// Contenedor de iCloud para cuando se active la sincronización.
    static let cloudKitContainerID = "iCloud.com.uvu.app"

    /// Si al abrir la app la base de datos no se pudo leer, se apartó a este archivo
    /// (no se borra) y se empezó una nueva. La app lo avisa en pantalla.
    static private(set) var setAsideStoreURL: URL?

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
        let schema = Schema(AppSchema.models)
        if inMemory {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("No se pudo crear la base de datos en memoria: \(error)")
            }
        }
        return makeContainer(url: storeURL)
    }

    static func makeContainer(url: URL) -> ModelContainer {
        let schema = Schema(AppSchema.models)
        // Para activar iCloud más adelante (requiere cuenta de Apple Developer):
        // cambiar `.none` por `.private(cloudKitContainerID)` y añadir la capacidad
        // iCloud + CloudKit al target en project.yml.
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // Antes que dejar la app cerrándose sola en cada arranque, se aparta la base
            // dañada (sigue en el teléfono para poder recuperarla) y se abre una nueva.
            setAsideStoreURL = setAside(storeAt: url)
            do {
                return try ModelContainer(for: schema, configurations: configuration)
            } catch {
                fatalError("No se pudo abrir la base de datos: \(error)")
            }
        }
    }

    private static func setAside(storeAt url: URL) -> URL? {
        let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "-")
        let target = url.deletingLastPathComponent().appending(path: "UVU-apartada-\(stamp).store")
        let fileManager = FileManager.default
        var moved = false
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let destination = URL(fileURLWithPath: target.path + suffix)
            if (try? fileManager.moveItem(at: source, to: destination)) != nil {
                moved = true
            }
        }
        return moved ? target : nil
    }
}
