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

        List {
            Section {
                HStack(spacing: 14) {
                    SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.name)
                            .font(.title3.bold())
                        Text("\(habit.frequencyDescription) · \(habit.goalDescription)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let reminder = reminderText {
                            Label(reminder, systemImage: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Estadísticas") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "Racha actual", value: "\(evaluator.currentStreak())",
                             unit: evaluator.streakUnit, symbol: "flame.fill", tint: .orange)
                    StatTile(title: "Mejor racha", value: "\(evaluator.bestStreak())",
                             unit: evaluator.streakUnit, symbol: "trophy.fill", tint: .yellow)
                    StatTile(title: "Esta semana", value: percent(evaluator.weeklyRate()),
                             unit: "", symbol: "calendar", tint: .blue)
                    StatTile(title: "Este mes", value: percent(evaluator.monthlyRate()),
                             unit: "", symbol: "chart.bar.fill", tint: .green)
                }
                .padding(.vertical, 4)
            }

            Section {
                MonthCalendarView(month: $month) { day in
                    let status = evaluator.status(on: day)
                    Button {
                        selectedDay = SelectedDay(date: day)
                    } label: {
                        CalendarDayCell(date: day, fill: status.fillColor, textColor: status.textColor,
                                        accessibilityStatus: status.title)
                    }
                    .buttonStyle(.borderless)
                    .disabled(status == .future)
                }
                HabitStatusLegend()
            } footer: {
                Text("Toca un día para marcarlo o corregirlo.")
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Editar") { showEdit = true }
        }
        .sheet(isPresented: $showEdit) {
            HabitFormView(habit: habit, onArchive: { dismiss() })
        }
        .sheet(item: $selectedDay) { selection in
            HabitDayEditorSheet(habit: habit, day: selection.date)
        }
    }

    private var reminderText: String? {
        guard let hour = habit.reminderHour, let minute = habit.reminderMinute else { return nil }
        let date = AppCalendar.calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
        return "Recordatorio a las \(date.formatted(date: .omitted, time: .shortened))"
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.formatted(.percent.precision(.fractionLength(0)).locale(AppLocale.spanish))
    }
}

/// Recuadro con un número grande y su descripción.
struct StatTile: View {
    let title: String
    let value: String
    let unit: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(TintedIconLabelStyle(tint: tint))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}
