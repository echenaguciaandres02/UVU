import SwiftUI
import SwiftData

struct GymHomeView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section(group.muscle.title) {
                        ForEach(group.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                if !exercise.equipment.isEmpty {
                                    Text(exercise.equipment)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gym")
            .safeAreaInset(edge: .bottom) {
                Text("Rutinas, sesiones en vivo y progreso llegan en la fase 5.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
    }

    private var groups: [ExerciseGroup] {
        MuscleGroup.allCases.compactMap { muscle in
            let items = exercises.filter { $0.muscleGroup == muscle }
            return items.isEmpty ? nil : ExerciseGroup(muscle: muscle, exercises: items)
        }
    }
}

struct ExerciseGroup: Identifiable {
    let muscle: MuscleGroup
    let exercises: [Exercise]

    var id: MuscleGroup { muscle }
}

#Preview {
    GymHomeView()
        .modelContainer(PreviewData.container)
}
