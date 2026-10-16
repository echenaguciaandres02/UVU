import SwiftUI

enum AppTab: Hashable {
    case today
    case habits
    case tasks
    case journal
    case gym
}

struct RootTabView: View {
    @State private var selection: AppTab = .today

    var body: some View {
        TabView(selection: $selection) {
            TodayView()
                .tabItem { Label("Hoy", systemImage: "sun.max.fill") }
                .tag(AppTab.today)

            HabitsHomeView()
                .tabItem { Label("Hábitos", systemImage: "checkmark.circle.fill") }
                .tag(AppTab.habits)

            TasksHomeView()
                .tabItem { Label("Tareas", systemImage: "checklist") }
                .tag(AppTab.tasks)

            JournalHomeView()
                .tabItem { Label("Journal", systemImage: "book.closed.fill") }
                .tag(AppTab.journal)

            GymHomeView()
                .tabItem { Label("Gym", systemImage: "dumbbell.fill") }
                .tag(AppTab.gym)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}
