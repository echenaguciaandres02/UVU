import SwiftUI
import SwiftData
import Charts

/// Progreso de un ejercicio: récords (peso máximo y 1RM estimado), gráficas de peso máximo y
/// volumen por sesión, e historial de series.
struct ExerciseProgressView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var metric: ProgressMetric = .maxWeight
    @State private var confirmDelete = false

    var body: some View {
        let stats = WorkoutActions.stats(for: exercise, unit: weightUnit)
        let records = ExerciseStatsCalculator.records(stats)

        List {
            Section {
                HStack(spacing: Space.xs) {
                    RecordTile(title: "Peso máximo", value: records.maxWeight, unit: weightUnit, date: records.maxWeightDate)
                    RecordTile(title: "1RM estimado", value: records.bestOneRepMax, unit: weightUnit,
                               date: records.bestOneRepMaxDate)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.m, bottom: Space.xs, trailing: Space.m))
            } header: {
                Text("\(exercise.muscleGroup.title) · \(exercise.equipment)").labelCaps()
            }

            if stats.count >= 1 {
                Section {
                    ScopeBar(options: ProgressMetric.allCases, selection: $metric, title: \.title)
                    ProgressChart(stats: stats, metric: metric, unit: weightUnit, records: records)
                        .frame(height: 220)
                        .padding(.vertical, Space.xs)
                } header: {
                    Text("Progreso").labelCaps()
                } footer: {
                    Text(metric.footer).formFooter()
                }
                .rowSurface()

                Section {
                    ForEach(historyItems) { item in
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            Text(PosterHeader.dateLine(item.session?.startedAt ?? .now)).labelCaps(10, .semibold)
                            Text(WorkoutActions.describe(item.completedSets) ?? "")
                                .font(.ui(15, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.bone)
                        }
                        .padding(.vertical, Space.xxs)
                    }
                } header: {
                    Text("Historial").labelCaps()
                }
                .rowSurface()
            } else {
                Section {
                    RedPoster(text: Quotes.empty, caption: "Registra este ejercicio en un entreno", minHeight: 180)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }

            if exercise.isCustom {
                Section {
                    Button("Borrar ejercicio") { confirmDelete = true }
                        .buttonStyle(.uvuSecondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .screenBackground()
        .navigationTitle(exercise.name.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Borrar \"\(exercise.name)\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                context.delete(exercise)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Se quita de la biblioteca y de las rutinas. Las series del historial se conservan sin nombre.")
        }
    }

    private var historyItems: [SessionExercise] {
        (exercise.sessionItems ?? [])
            .filter { $0.session?.endedAt != nil && !$0.completedSets.isEmpty }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
    }
}

enum ProgressMetric: String, CaseIterable, Identifiable {
    case maxWeight
    case oneRepMax
    case volume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maxWeight: return "Peso máx."
        case .oneRepMax: return "1RM"
        case .volume: return "Volumen"
        }
    }

    var footer: String {
        switch self {
        case .maxWeight: return "La serie más pesada de cada sesión. El punto rojo es tu récord."
        case .oneRepMax: return "1RM estimado (Epley): combina peso y repeticiones. El punto rojo es tu récord."
        case .volume: return "Peso × repeticiones sumado en cada sesión."
        }
    }

    func value(_ stat: ExerciseSessionStat) -> Double {
        switch self {
        case .maxWeight: return stat.maxWeight
        case .oneRepMax: return stat.bestOneRepMax
        case .volume: return stat.volume
        }
    }
}

private struct ProgressChart: View {
    let stats: [ExerciseSessionStat]
    let metric: ProgressMetric
    let unit: WeightUnit
    let records: ExerciseRecords

    var body: some View {
        let recordValue: Double? = {
            switch metric {
            case .maxWeight: return records.maxWeight
            case .oneRepMax: return records.bestOneRepMax
            case .volume: return nil
            }
        }()

        Chart {
            ForEach(stats) { stat in
                let value = metric.value(stat)
                if metric == .volume {
                    BarMark(x: .value("Fecha", stat.date, unit: .day), y: .value("Volumen", value))
                        .foregroundStyle(Color.bone)
                } else {
                    LineMark(x: .value("Fecha", stat.date, unit: .day), y: .value(metric.title, value))
                        .foregroundStyle(Color.bone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Fecha", stat.date, unit: .day), y: .value(metric.title, value))
                        .foregroundStyle(isRecord(value, recordValue) ? Color.signal : .bone)
                        .symbolSize(isRecord(value, recordValue) ? 120 : 30)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.graphite)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(AppLocale.spanish))
                    .foregroundStyle(Color.ash)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.graphite)
                AxisValueLabel().foregroundStyle(Color.ash)
            }
        }
        .chartYAxisLabel(metric == .volume ? unit.rawValue : unit.rawValue, position: .topLeading)
        .accessibilityLabel("Gráfica de \(metric.title) por sesión")
    }

    private func isRecord(_ value: Double, _ record: Double?) -> Bool {
        guard let record, record > 0 else { return false }
        return abs(value - record) < 0.0001
    }
}

private struct RecordTile: View {
    let title: String
    let value: Double
    let unit: WeightUnit
    let date: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xxs) {
                Text(value > 0 ? NumberText.format((value * 10).rounded() / 10) : "—")
                    .font(.numeral(40, weight: .thin, relativeTo: .title1))
                    .monospacedDigit()
                    .foregroundStyle(.bone)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if value > 0 {
                    Text(unit.rawValue).labelCaps(11, .semibold)
                }
            }
            Text(title).labelCaps(10, .black, color: value > 0 ? .brass : .ash)
            if let date {
                Text(PosterHeader.dateLine(date)).labelCaps(9, .semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: Space.s)
        .accessibilityElement(children: .combine)
    }
}
