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
                            // En Hoy y Todas la sección ya dice la lista; la franja de color la repite.
                            TaskRowView(task: task, showList: section.list == nil) { editingTask = task }
                                .taskRowSurface(task.list)
                        }
                    } header: {
                        HStack(spacing: Space.xs) {
                            if let list = section.list {
                                SymbolBadge(symbol: list.symbol, colorHex: list.colorHex, size: 22)
                                Text(section.title).labelCaps(12, .black, color: .bone)
                            } else {
                                Text(section.title).labelCaps(12, .semibold)
                            }
                            Spacer()
                            Text("\(section.tasks.count)").labelCaps(12, .semibold)
                        }
                        .padding(.top, Space.xs)
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
