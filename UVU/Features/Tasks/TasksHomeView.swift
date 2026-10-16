import SwiftUI
import SwiftData

struct TasksHomeView: View {
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]

    @State private var scope: TaskScope = .today
    @State private var path: [TasksRoute] = []
    @State private var editingTask: TaskItem?
    @State private var showNewTask = false

    var body: some View {
        let sections = TaskGrouping.sections(for: scope, tasks: tasks)

        NavigationStack(path: $path) {
            List {
                Section {
                    ScopeBar(options: TaskScope.allCases, selection: $scope, title: \.title) { option in
                        option == .today ? todayCount : nil
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: 0, trailing: Space.m))
                }

                if sections.isEmpty {
                    Section {
                        RedPoster(text: emptyTitle, caption: emptyCaption, minHeight: 200)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }

                ForEach(sections) { section in
                    Section {
                        ForEach(section.tasks) { task in
                            TaskRowView(task: task, showList: scope != .all) { editingTask = task }
                                .rowSurface()
                        }
                    } header: {
                        HStack {
                            Text(section.title).labelCaps(12, .semibold, color: section.id == "overdue" ? .bone : .ash)
                            Spacer()
                            Text("\(section.tasks.count)").labelCaps(12, .semibold)
                        }
                    }
                }
            }
            .screenBackground()
            .animation(Motion.quick, value: scope)
            .navigationTitle("TAREAS")
            .navigationDestination(for: TasksRoute.self) { route in
                switch route {
                case .lists:
                    TaskListsView()
                case .list(let list):
                    ListTasksView(list: list)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        path.append(.lists)
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .fontWeight(.bold)
                    }
                    .accessibilityLabel("Mis listas")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewTask = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                    }
                    .accessibilityLabel("Nueva tarea")
                }
            }
            .sheet(isPresented: $showNewTask) {
                TaskFormView(task: nil, defaultDue: scope == .today ? .now : nil)
            }
            .sheet(item: $editingTask) { task in
                TaskFormView(task: task)
            }
        }
    }

    private var todayCount: Int {
        tasks.filter { !$0.isCompleted && TaskSchedule.isDueTodayOrOverdue(due: $0.dueDate) }.count
    }

    private var emptyTitle: String {
        switch scope {
        case .today: return "Nada pendiente hoy."
        case .upcoming, .all: return Quotes.empty
        case .completed: return "Nada hecho. Todavía."
        }
    }

    private var emptyCaption: String {
        switch scope {
        case .today, .upcoming, .all: return "Toca + para agregar una tarea"
        case .completed: return "Desliza a la derecha para completar"
        }
    }
}

enum TasksRoute: Hashable {
    case lists
    case list(TaskList)
}

#Preview {
    TasksHomeView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
