import SwiftUI
import SwiftData

/// Fila de una tarea: checkbox que se estampa, título y datos (vence, lista, subtareas, repetición).
/// Deslizar a la derecha completa (o reabre); a la izquierda borra.
struct TaskRowView: View {
    let task: TaskItem
    var showList = true
    var onOpen: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        let overdue = TaskSchedule.isOverdue(due: task.dueDate, hasTime: task.hasTime, isCompleted: task.isCompleted)

        HStack(alignment: .top, spacing: Space.s) {
            Button {
                toggle()
            } label: {
                HabitCheckbox(progress: task.isCompleted ? 1 : 0, size: 26)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(task.isCompleted ? "Reabrir \(task.title)" : "Completar \(task.title)")

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                        if task.priority != .none {
                            Text(String(repeating: "!", count: task.priority.rawValue))
                                .font(.ui(16, .black))
                                .foregroundStyle(task.priority == .high ? Color.bone : .ash)
                                .accessibilityLabel("Prioridad \(task.priority.title)")
                        }
                        Text(task.title)
                            .font(.ui(16, .semibold, relativeTo: .body))
                            .foregroundStyle(task.isCompleted ? Color.ash : .bone)
                            .strikethrough(task.isCompleted, color: .ash)
                            .multilineTextAlignment(.leading)
                    }
                    meta(overdue: overdue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Space.xxs)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                toggle()
            } label: {
                Label(task.isCompleted ? "Reabrir" : "Completar",
                      systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.isCompleted ? .graphite : .signal)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation(Motion.quick) { TaskActions.delete(task, in: context) }
            } label: {
                Label("Borrar", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func meta(overdue: Bool) -> some View {
        let parts = metaParts
        if !parts.isEmpty || overdue {
            HStack(spacing: Space.xs) {
                if overdue {
                    // Marcador rojo (relleno) en vez de texto rojo pequeño.
                    Rectangle().fill(.signal).frame(width: 6, height: 6)
                    Text("Atrasada").labelCaps(10, .black, color: .bone)
                }
                ForEach(parts, id: \.self) { part in
                    Text(part).labelCaps(10, .semibold)
                }
                if task.recurrence != .none {
                    Image(systemName: "repeat")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.ash)
                        .accessibilityLabel("Se repite: \(task.recurrence.title)")
                }
                if task.dueDate != nil && task.reminderEnabled && !task.isCompleted {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.ash)
                        .accessibilityLabel("Con aviso")
                }
            }
            .lineLimit(1)
        }
    }

    private var metaParts: [String] {
        var parts: [String] = []
        if let due = task.dueDate {
            parts.append(TaskSchedule.dueDescription(due: due, hasTime: task.hasTime))
        }
        if showList, let list = task.list?.name {
            parts.append(list)
        }
        if let progress = task.subtaskProgress {
            parts.append(progress)
        }
        return parts
    }

    private func toggle() {
        withAnimation(Motion.quick) {
            if task.isCompleted {
                TaskActions.reopen(task, in: context)
                Haptics.tap()
            } else {
                TaskActions.complete(task, in: context)
                Haptics.stamp()
            }
        }
    }
}
