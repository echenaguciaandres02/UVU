import SwiftUI
import SwiftData

struct GymHomeView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    RedPoster(text: "Cada repetición cuenta.",
                              caption: "Rutinas y sesiones en vivo: fase 5",
                              minHeight: 170, textSize: 44)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                ForEach(groups) { group in
                    Section {
                        ForEach(group.exercises) { exercise in
                            HStack {
                                Text(exercise.name)
                                    .font(.ui(16, .semibold))
                                    .foregroundStyle(.bone)
                                Spacer()
                                if !exercise.equipment.isEmpty {
                                    Text(exercise.equipment)
                                        .labelCaps(10, .semibold)
                                }
                            }
                            .rowSurface()
                        }
                    } header: {
                        Text(group.muscle.title).labelCaps()
                    }
                }
            }
            .screenBackground()
            .navigationTitle("GYM")
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
        .preferredColorScheme(.dark)
}
