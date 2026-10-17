import SwiftUI
import SwiftData

/// Detalle de un entreno terminado: resumen y series por ejercicio, con los récords marcados.
struct SessionDetailView: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var confirmDelete = false

    var body: some View {
        let records = Set(WorkoutActions.recordExercises(in: session, unit: weightUnit))

        List {
            Section {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(session.routine?.name ?? "Entreno libre").posterTitle(44, relativeTo: .title)
                    Text(PosterHeader.dateLine(session.startedAt)).labelCaps(12, .semibold)
                }
                .listRowBackground(Color.clear)

                HStack(spacing: Space.xs) {
                    StatTile(title: "Duración",
                             value: GymMath.duration((session.endedAt ?? .now).timeIntervalSince(session.startedAt)))
                    StatTile(title: "Series", value: "\(session.sortedExercises.flatMap(\.completedSets).count)")
                    StatTile(title: "Volumen",
                             value: GymMath.format(WorkoutActions.volume(of: session, unit: weightUnit), unit: weightUnit))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: Space.xs, trailing: Space.m))
            }

            ForEach(session.sortedExercises) { item in
                Section {
                    ForEach(Array(item.completedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .font(.numeral(18, weight: .thin, relativeTo: .body))
                                .foregroundStyle(.ash)
                                .frame(width: 24)
                            Text("\(GymMath.format(set.weight, unit: set.unit)) × \(set.reps)")
                                .font(.ui(16, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.bone)
                            Spacer()
                            if let rpe = set.rpe {
                                Text("RPE \(NumberText.format(rpe))").labelCaps(10, .semibold)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(item.exercise?.name ?? "Ejercicio borrado")
                            .font(.ui(15, .black, relativeTo: .subheadline))
                            .textCase(.uppercase)
                            .foregroundStyle(.bone)
                        if let name = item.exercise?.name, records.contains(name) {
                            Text("PR").labelCaps(11, .black, color: .brass)
                        }
                    }
                }
                .rowSurface()
            }

            Section {
                Button("Borrar entreno") { confirmDelete = true }
                    .buttonStyle(.uvuSecondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .screenBackground()
        .navigationTitle("ENTRENO")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Borrar este entreno?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                context.delete(session)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Se borra del historial y de las gráficas. El hábito \"Ejercicio\" de ese día no cambia.")
        }
    }
}
