import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let habit: Habit

    @Environment(\.dismiss) private var dismiss
    @State private var month = Date.now
    @State private var selectedDay: SelectedDay?
    @State private var showEdit = false

    var body: some View {
        let evaluator = HabitEvaluator(habit: habit)
        let current = evaluator.currentStreak()
        let best = evaluator.bestStreak()

        List {
            Section {
                HStack(spacing: Space.m) {
                    SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex, size: 52)
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("\(habit.frequencyDescription) · \(habit.goalDescription)")
                            .font(.uiCallout)
                            .foregroundStyle(.bone)
                        if let reminder = reminderText {
                            Label(reminder, systemImage: "bell.fill")
                                .labelCaps(11, .semibold)
                        }
                    }
                }
                .padding(.vertical, Space.xxs)
                .rowSurface()
            }

            Section {
                StreakCounter(value: current, unit: evaluator.streakUnit,
                              isRecord: current > 0 && current >= best)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.m, bottom: Space.xs, trailing: Space.m))

                HStack(spacing: Space.xs) {
                    StatTile(title: "Mejor racha", value: "\(best)", isHighlight: best > 0 && current >= best)
                    StatTile(title: "Semana", value: percent(evaluator.weeklyRate()))
                    StatTile(title: "Mes", value: percent(evaluator.monthlyRate()))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: Space.xs, trailing: Space.m))
            }

            Section {
                MonthCalendarView(month: $month) { day in
                    let status = evaluator.status(on: day)
                    Button {
                        selectedDay = SelectedDay(date: day)
                    } label: {
                        CalendarDayCell(date: day, status: status)
                    }
                    .buttonStyle(.borderless)
                    .disabled(status == .future)
                }
                .padding(.vertical, Space.xs)
                HabitStatusLegend()
                    .padding(.bottom, Space.xs)
            } footer: {
                Text("Toca un día para marcarlo o corregirlo.")
                    .font(.uiFootnote)
                    .foregroundStyle(.ash)
            }
            .rowSurface()
        }
        .screenBackground()
        .navigationTitle(habit.name.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Editar") { showEdit = true }
                .font(.ui(16, .semibold))
        }
        .sheet(isPresented: $showEdit) {
            HabitFormView(habit: habit, onArchive: { dismiss() })
        }
        .sheet(item: $selectedDay) { selection in
            HabitDayEditorSheet(habit: habit, day: selection.date)
        }
    }

    private var reminderText: String? {
        guard let times = habit.remindersDescription else { return nil }
        return habit.reminderMinutes.count == 1 ? "Recordatorio \(times)" : "Recordatorios \(times)"
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(0)).locale(AppLocale.spanish))
    }
}

/// Recuadro con un número fino y su etiqueta. `isHighlight` pinta la etiqueta en `brass` (récord).
struct StatTile: View {
    let title: String
    let value: String
    var isHighlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(value)
                .font(.numeral(34, weight: .thin, relativeTo: .title1))
                .monospacedDigit()
                .foregroundStyle(.bone)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .labelCaps(10, .semibold, color: isHighlight ? .brass : .ash)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(padding: Space.s)
        .accessibilityElement(children: .combine)
    }
}
