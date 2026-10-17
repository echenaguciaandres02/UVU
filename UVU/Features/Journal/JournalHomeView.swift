import SwiftUI
import SwiftData

enum JournalMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "Entradas"
        case .calendar: return "Calendario"
        }
    }
}

struct JournalHomeView: View {
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @AppStorage(JournalLock.enabledKey) private var lockEnabled = false

    @State private var lock = JournalLock.shared
    @State private var mode: JournalMode = .list
    @State private var query = ""
    @State private var selectedTag: String?
    @State private var month = Date.now
    @State private var editingDay: SelectedDay?

    var body: some View {
        NavigationStack {
            Group {
                if lockEnabled && !lock.isUnlocked {
                    JournalLockedView(lock: lock)
                } else {
                    content
                }
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("JOURNAL")
            .toolbar {
                if !lockEnabled || lock.isUnlocked {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editingDay = SelectedDay(date: AppCalendar.startOfDay(.now))
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .fontWeight(.bold)
                        }
                        .accessibilityLabel("Escribir hoy")
                    }
                }
            }
            .sheet(item: $editingDay) { selection in
                JournalEditorView(day: selection.date)
            }
        }
    }

    // MARK: - Contenido

    private var content: some View {
        let filtered = JournalStore.filter(entries, query: query, tag: selectedTag)
        let today = entries.first { AppCalendar.calendar.isDateInToday($0.date) }

        return List {
            Section {
                TodayJournalCard(entry: today) {
                    editingDay = SelectedDay(date: AppCalendar.startOfDay(.now))
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.m, bottom: Space.xs, trailing: Space.m))

                ScopeBar(options: JournalMode.allCases, selection: $mode, title: \.title)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: 0, trailing: Space.m))
            }

            switch mode {
            case .list:
                listSections(filtered)
            case .calendar:
                calendarSection
            }
        }
        .screenBackground()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Buscar en el journal")
    }

    @ViewBuilder
    private func listSections(_ filtered: [JournalEntry]) -> some View {
        let allTags = Array(Set(entries.flatMap(\.sortedTagNames))).sorted()
        if !allTags.isEmpty {
            Section {
                TagChips(tags: allTags, selected: selectedTag, onTap: { tag in
                    withAnimation(Motion.quick) {
                        selectedTag = selectedTag.map { JournalStore.sameTag($0, tag) } == true ? nil : tag
                    }
                })
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: 0, trailing: Space.m))
            } header: {
                Text("Etiquetas").labelCaps()
            }
        }

        if filtered.isEmpty {
            Section {
                RedPoster(text: entries.isEmpty ? Quotes.empty : "Sin resultados.",
                          caption: entries.isEmpty ? "Escribe tu primera entrada" : "Prueba con otra palabra o etiqueta",
                          minHeight: 180)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        } else {
            ForEach(monthGroups(filtered), id: \.month) { group in
                Section {
                    ForEach(group.entries) { entry in
                        Button {
                            editingDay = SelectedDay(date: entry.date)
                        } label: {
                            JournalEntryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .rowSurface()
                    }
                } header: {
                    Text(group.title).labelCaps()
                }
            }
        }
    }

    private var calendarSection: some View {
        let byDay = Dictionary(entries.map { (AppCalendar.startOfDay($0.date), $0) }, uniquingKeysWith: { first, _ in first })
        return Section {
            MonthCalendarView(month: $month) { day in
                let entry = byDay[AppCalendar.startOfDay(day)]
                let isFuture = AppCalendar.startOfDay(day) > AppCalendar.startOfDay(.now)
                Button {
                    editingDay = SelectedDay(date: AppCalendar.startOfDay(day))
                } label: {
                    JournalDayCell(date: day, mood: entry?.mood, isFuture: isFuture)
                }
                .buttonStyle(.borderless)
                .disabled(isFuture)
            }
            .padding(.vertical, Space.xs)
            MoodLegend()
                .padding(.bottom, Space.xs)
        } footer: {
            Text("Cada cuadro es un día con entrada: más claro, mejor ánimo. Toca un día para escribir o leer.")
                .formFooter()
        }
        .rowSurface()
    }

    private struct MonthGroup {
        let month: Date
        let title: String
        let entries: [JournalEntry]
    }

    private func monthGroups(_ list: [JournalEntry]) -> [MonthGroup] {
        let calendar = AppCalendar.calendar
        let grouped = Dictionary(grouping: list) { entry in
            calendar.dateInterval(of: .month, for: entry.date)?.start ?? entry.date
        }
        return grouped.keys.sorted(by: >).map { month in
            MonthGroup(month: month,
                       title: month.formatted(.dateTime.month(.wide).year().locale(AppLocale.spanish)),
                       entries: (grouped[month] ?? []).sorted { $0.date > $1.date })
        }
    }
}

// MARK: - Piezas

/// Tarjeta de hoy: invita a escribir o resume la entrada ya escrita.
private struct TodayJournalCard: View {
    let entry: JournalEntry?
    var onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hoy").labelCaps(12, .black, color: .bone)
                Spacer()
                Text(PosterHeader.dateLine()).labelCaps(11, .semibold)
            }
            if let entry {
                HStack(spacing: Space.s) {
                    MoodBars(level: entry.mood)
                    Text(Mood.title(entry.mood)).labelCaps(12, .black, color: .bone)
                }
                if !entry.excerpt.isEmpty {
                    Text(entry.excerpt)
                        .font(.editorial(20, relativeTo: .title3))
                        .foregroundStyle(.bone)
                        .lineLimit(3)
                }
                Button("Seguir escribiendo", action: onWrite)
                    .buttonStyle(.uvuSecondary)
            } else {
                Text("¿Cómo fue tu día?")
                    .editorialQuote(28)
                    .frame(maxWidth: .infinity)
                Button("Escribir hoy", action: onWrite)
                    .buttonStyle(.uvuPrimary)
            }
        }
        .cardSurface()
    }
}

/// Fila de una entrada: número del día grande, ánimo, texto y etiquetas.
struct JournalEntryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            VStack(spacing: 0) {
                Text("\(AppCalendar.calendar.component(.day, from: entry.date))")
                    .font(.numeral(34, weight: .thin, relativeTo: .title1))
                    .monospacedDigit()
                    .foregroundStyle(.bone)
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).locale(AppLocale.spanish))
                    .replacingOccurrences(of: ".", with: ""))
                    .labelCaps(10, .semibold)
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.xs) {
                    MoodBars(level: entry.mood, height: 14, barWidth: 3)
                    Text(Mood.title(entry.mood)).labelCaps(10, .black, color: .bone)
                }
                if !entry.excerpt.isEmpty {
                    Text(entry.excerpt)
                        .font(.uiCallout)
                        .foregroundStyle(.bone)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                let tags = entry.sortedTagNames
                if !tags.isEmpty {
                    Text(tags.map { "#\($0)" }.joined(separator: "  "))
                        .labelCaps(10, .semibold)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Space.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Día del calendario del journal: gris según el ánimo si hay entrada.
struct JournalDayCell: View {
    let date: Date
    let mood: Int?
    var isFuture = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
        let isToday = AppCalendar.calendar.isDateInToday(date)
        ZStack {
            // Base siempre presente: sin ella, los días futuros (vacíos) no tienen tamaño y la fila se aplasta.
            Color.clear
            if let mood {
                shape.fill(Mood.shade(mood))
            } else if !isFuture {
                shape.strokeBorder(.graphite, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay {
            Text("\(AppCalendar.calendar.component(.day, from: date))")
                .font(.ui(15, isToday ? .black : .semibold, relativeTo: .callout))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(mood.map(Mood.numberColor) ?? (isFuture ? Color.ash.opacity(0.5) : .ash))
        }
        .overlay {
            if isToday {
                shape.strokeBorder(Color.bone, lineWidth: 2).padding(-3)
            }
        }
        .padding(3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.spanish))
        guard let mood else { return "\(day), sin entrada" }
        return "\(day), ánimo \(Mood.title(mood))"
    }
}

/// Leyenda de grises del ánimo.
private struct MoodLegend: View {
    var body: some View {
        HStack(spacing: Space.xs) {
            Text("Muy mal").labelCaps(10, .semibold)
            ForEach(Mood.range, id: \.self) { level in
                RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                    .fill(Mood.shade(level))
                    .frame(width: 18, height: 12)
            }
            Text("Muy bien").labelCaps(10, .semibold)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Del más oscuro, muy mal, al más claro, muy bien")
    }
}

/// Pantalla de bloqueo: póster rojo y botón para desbloquear con Face ID.
private struct JournalLockedView: View {
    let lock: JournalLock

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Spacer()
            RedPoster(text: "Privado.", caption: "Tu journal está protegido", minHeight: 260, textSize: 72)
            if let error = lock.lastError {
                Text(error)
                    .font(.uiCallout)
                    .foregroundStyle(.ash)
            }
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Desbloquear", systemImage: "faceid")
            }
            .buttonStyle(.uvuPrimary)
            .disabled(lock.isAuthenticating)
            Spacer()
        }
        .padding(Space.m)
        .task { await lock.unlock() }
    }
}

#Preview {
    JournalHomeView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
