import SwiftUI

/// Una hora de recordatorio editable en el formulario.
struct ReminderEntry: Identifiable {
    let id = UUID()
    var time: Date

    init(minutes: Int) {
        time = ReminderTime.date(from: minutes)
    }

    var minutes: Int { ReminderTime.minutes(from: time) }
}

/// Genera varios recordatorios de una vez: "cada 2 horas de 8:00 a 20:00".
struct SpreadRemindersSheet: View {
    var onApply: ([Int]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start = ReminderTime.date(from: 8 * 60)
    @State private var end = ReminderTime.date(from: 20 * 60)
    @State private var intervalMinutes = 120

    private let intervals = [30, 60, 90, 120, 180, 240]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Desde", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Hasta", selection: $end, displayedComponents: .hourAndMinute)
                    Picker("Cada", selection: $intervalMinutes) {
                        ForEach(intervals, id: \.self) { minutes in
                            Text(intervalTitle(minutes)).tag(minutes)
                        }
                    }
                }
                .rowSurface()

                Section {
                    Text(preview.map(ReminderTime.format).joined(separator: " · "))
                        .font(.ui(15, .regular, relativeTo: .subheadline))
                        .monospacedDigit()
                        .foregroundStyle(.ash)
                } header: {
                    Text("\(preview.count) recordatorios").labelCaps()
                } footer: {
                    Text("Reemplaza los recordatorios actuales del hábito. Máximo \(ReminderTime.maxPerHabit).")
                        .formFooter()
                }
                .rowSurface()
            }
            .uvuForm()
            .navigationTitle("REPARTIR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        onApply(preview)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(preview.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.ink)
    }

    private var preview: [Int] {
        ReminderTime.spread(from: ReminderTime.minutes(from: start), to: ReminderTime.minutes(from: end),
                            every: intervalMinutes)
    }

    private func intervalTitle(_ minutes: Int) -> String {
        switch minutes {
        case 30: return "30 min"
        case 60: return "1 hora"
        case 90: return "1 h 30 min"
        default: return "\(minutes / 60) horas"
        }
    }
}
