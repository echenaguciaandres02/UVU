import Foundation
import SwiftData

/// Datos iniciales: tus hábitos actuales, listas de tareas y la biblioteca de ejercicios.
@MainActor
enum SeedData {
    private static let seededKey = "uvu.seeded.v1"
    private static let habitsV2Key = "uvu.seeded.v2.habits"

    /// Carga los datos iniciales solo la primera vez que se abre la app, y agrega
    /// a una instalación existente los hábitos precargados que se sumaron después.
    static func seedIfNeeded(context: ModelContext, defaults: UserDefaults = .standard) {
        if !defaults.bool(forKey: seededKey) {
            seed(context: context)
            defaults.set(true, forKey: seededKey)
            defaults.set(true, forKey: habitsV2Key)
        } else if !defaults.bool(forKey: habitsV2Key) {
            addMissingHabits(habitsAddedInV2(), context: context)
            defaults.set(true, forKey: habitsV2Key)
        }
    }

    /// Hábitos que se agregaron después de la primera versión.
    static func habitsAddedInV2() -> [Habit] {
        [
            Habit(name: "Tomar creatina", symbol: "pills.fill", colorHex: "00C7BE"),
            Habit(name: "Proteína", symbol: "fork.knife", colorHex: "FF2D55",
                  kind: .quantity, target: 130, unit: "g"),
            Habit(name: "Aprender algo nuevo", symbol: "lightbulb.fill", colorHex: "AF52DE"),
        ]
    }

    private static func addMissingHabits(_ newHabits: [Habit], context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let names = Set(existing.map { $0.name.lowercased() })
        var nextOrder = (existing.map(\.sortOrder).max() ?? -1) + 1
        for habit in newHabits where !names.contains(habit.name.lowercased()) {
            habit.sortOrder = nextOrder
            nextOrder += 1
            context.insert(habit)
        }
        try? context.save()
    }

    static func seed(context: ModelContext) {
        var habits = [
            Habit(name: "Ejercicio", symbol: "figure.strengthtraining.traditional", colorHex: "FF9500",
                  sortOrder: 0, systemRole: HabitSystemRole.exercise),
            Habit(name: "Tomar agua", symbol: "drop.fill", colorHex: "007AFF",
                  kind: .quantity, target: 8, unit: "vasos", sortOrder: 1),
            Habit(name: "Trabajar en la tesis", symbol: "graduationcap.fill", colorHex: "5856D6",
                  kind: .quantity, target: 60, unit: "min", sortOrder: 2),
            Habit(name: "Tomar sol", symbol: "sun.max.fill", colorHex: "FFCC00",
                  kind: .quantity, target: 15, unit: "min", sortOrder: 3),
            Habit(name: "Lectura", symbol: "book.fill", colorHex: "34C759",
                  kind: .quantity, target: 20, unit: "páginas", sortOrder: 4),
        ]
        habits += habitsAddedInV2()
        for (index, habit) in habits.enumerated() {
            habit.sortOrder = index
            context.insert(habit)
        }

        let lists = [
            TaskList(name: "Personal", symbol: "person.fill", colorHex: "007AFF", sortOrder: 0),
            TaskList(name: "Trabajo", symbol: "briefcase.fill", colorHex: "FF9500", sortOrder: 1),
            TaskList(name: "Universidad", symbol: "graduationcap.fill", colorHex: "AF52DE", sortOrder: 2),
        ]
        lists.forEach { context.insert($0) }

        for (muscle, items) in exerciseLibrary {
            for (name, equipment) in items {
                context.insert(Exercise(name: name, muscle: muscle, equipment: equipment))
            }
        }

        try? context.save()
    }

    static let exerciseLibrary: [(MuscleGroup, [(String, String)])] = [
        (.chest, [
            ("Press de banca", "Barra"),
            ("Press inclinado con mancuernas", "Mancuernas"),
            ("Aperturas con mancuernas", "Mancuernas"),
            ("Cruce de poleas", "Polea"),
            ("Fondos en paralelas", "Peso corporal"),
            ("Flexiones", "Peso corporal"),
        ]),
        (.back, [
            ("Dominadas", "Peso corporal"),
            ("Jalón al pecho", "Polea"),
            ("Remo con barra", "Barra"),
            ("Remo con mancuerna", "Mancuernas"),
            ("Remo en polea baja", "Polea"),
            ("Peso muerto", "Barra"),
        ]),
        (.legs, [
            ("Sentadilla", "Barra"),
            ("Prensa de piernas", "Máquina"),
            ("Zancadas", "Mancuernas"),
            ("Extensión de cuádriceps", "Máquina"),
            ("Curl femoral", "Máquina"),
            ("Peso muerto rumano", "Barra"),
            ("Elevación de talones", "Máquina"),
        ]),
        (.glutes, [
            ("Hip thrust", "Barra"),
            ("Patada de glúteo en polea", "Polea"),
        ]),
        (.shoulders, [
            ("Press militar", "Barra"),
            ("Press de hombros con mancuernas", "Mancuernas"),
            ("Elevaciones laterales", "Mancuernas"),
            ("Pájaros (deltoide posterior)", "Mancuernas"),
            ("Face pull", "Polea"),
        ]),
        (.biceps, [
            ("Curl con barra", "Barra"),
            ("Curl con mancuernas", "Mancuernas"),
            ("Curl martillo", "Mancuernas"),
            ("Curl en predicador", "Máquina"),
        ]),
        (.triceps, [
            ("Press francés", "Barra"),
            ("Extensión de tríceps en polea", "Polea"),
            ("Press cerrado", "Barra"),
            ("Extensión sobre la cabeza", "Mancuernas"),
        ]),
        (.core, [
            ("Plancha", "Peso corporal"),
            ("Crunch abdominal", "Peso corporal"),
            ("Elevación de piernas", "Peso corporal"),
            ("Rueda abdominal", "Accesorio"),
        ]),
        (.cardio, [
            ("Correr", "Cinta"),
            ("Bicicleta", "Máquina"),
            ("Remo (máquina)", "Máquina"),
        ]),
    ]
}
