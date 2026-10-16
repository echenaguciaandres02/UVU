import Foundation

/// Estado de un hábito en un día concreto (lo que define el color del calendario).
enum HabitDayStatus: Equatable {
    /// Meta cumplida (verde).
    case completed
    /// Algo de avance pero sin llegar a la meta (amarillo).
    case partial
    /// No se cumplió y tocaba hacerlo (rojo).
    case failed
    /// Ese día no tocaba (gris).
    case notApplicable
    /// Hoy, todavía sin hacer: no se pinta de rojo hasta que termine el día.
    case pending
    /// Día futuro: no se colorea.
    case future
}

/// Reglas de un hábito, separadas del modelo de SwiftData para poder probarlas.
struct HabitRules {
    var kind: HabitKind
    var target: Double
    var frequency: HabitFrequency
    var weekdays: Set<Int>
    var timesPerWeek: Int
    var createdAt: Date
}

extension HabitRules {
    init(_ habit: Habit) {
        self.init(kind: habit.kind, target: habit.target, frequency: habit.frequency,
                  weekdays: Set(habit.weekdays), timesPerWeek: habit.timesPerWeek, createdAt: habit.createdAt)
    }
}

/// Calcula estados diarios, rachas y porcentajes de cumplimiento de un hábito.
///
/// Reglas:
/// - Diario / días específicos: cada día que toca es verde (meta), amarillo (avance parcial) o rojo.
/// - X veces por semana: los días hechos son verdes. Los días sin hacer son grises mientras la
///   meta semanal se pueda cumplir o ya se haya cumplido; si la semana termina (o ya no da el
///   tiempo) sin llegar a la meta, esos días pasan a rojo. La racha se cuenta en semanas.
/// - Hoy nunca es rojo; los días antes de crear el hábito, sin registro, son grises.
struct HabitEvaluator {
    let rules: HabitRules
    let values: [Date: Double]
    let today: Date

    private var calendar: Calendar { AppCalendar.calendar }

    init(rules: HabitRules, values: [Date: Double], today: Date = .now) {
        self.rules = rules
        var normalized: [Date: Double] = [:]
        for (date, value) in values {
            normalized[AppCalendar.startOfDay(date), default: 0] += value
        }
        self.values = normalized
        self.today = AppCalendar.startOfDay(today)
    }

    init(habit: Habit, today: Date = .now) {
        var values: [Date: Double] = [:]
        for entry in habit.entries ?? [] {
            values[entry.date, default: 0] += entry.value
        }
        self.init(rules: HabitRules(habit), values: values, today: today)
    }

    // MARK: - Valores

    /// Cantidad que cuenta como "cumplido" (1 para hábitos sí/no).
    var goal: Double {
        rules.kind == .binary ? 1 : max(rules.target, 0.0001)
    }

    var streakUnit: String {
        rules.frequency == .timesPerWeek ? "semanas" : "días"
    }

    func value(on date: Date) -> Double {
        values[AppCalendar.startOfDay(date)] ?? 0
    }

    func isCompleted(_ value: Double) -> Bool {
        value >= goal - 0.000_001
    }

    func progress(on date: Date) -> Double {
        min(value(on: date) / goal, 1)
    }

    /// Si el hábito "toca" ese día según su frecuencia.
    func isScheduled(on date: Date) -> Bool {
        switch rules.frequency {
        case .daily, .timesPerWeek:
            return true
        case .specificDays:
            return rules.weekdays.contains(AppCalendar.weekday(of: date))
        }
    }

    private var createdDay: Date { AppCalendar.startOfDay(rules.createdAt) }

    /// Primer día que se tiene en cuenta: la creación o el primer registro, lo que sea antes.
    private var earliestDay: Date {
        let firstEntry = values.filter { $0.value > 0 }.keys.min()
        return min(createdDay, firstEntry ?? createdDay)
    }

    // MARK: - Estado por día

    func status(on date: Date) -> HabitDayStatus {
        let day = AppCalendar.startOfDay(date)
        if day > today { return .future }

        let value = value(on: day)
        if isCompleted(value) { return .completed }
        if value <= 0 && day < createdDay { return .notApplicable }

        switch rules.frequency {
        case .daily, .specificDays:
            guard isScheduled(on: day) else { return value > 0 ? .partial : .notApplicable }
            if day == today { return value > 0 ? .partial : .pending }
            return value > 0 ? .partial : .failed

        case .timesPerWeek:
            let week = weekInterval(containing: day)
            let done = completedDays(in: week)
            if done >= rules.timesPerWeek { return value > 0 ? .partial : .notApplicable }
            if value > 0 { return .partial }
            if day == today { return .pending }
            if week.end <= today { return .failed }
            // Semana en curso: rojo solo si ya no da el tiempo para llegar a la meta.
            let remainingDays = calendar.dateComponents([.day], from: today, to: week.end).day ?? 0
            return done + remainingDays < rules.timesPerWeek ? .failed : .notApplicable
        }
    }

    // MARK: - Rachas

    func currentStreak() -> Int {
        if rules.frequency == .timesPerWeek { return currentWeekStreak() }

        var count = 0
        var day = today
        if !isCompleted(value(on: today)) {
            day = previousDay(day)
        }
        while day >= earliestDay {
            if isScheduled(on: day) {
                guard isCompleted(value(on: day)) else { break }
                count += 1
            }
            day = previousDay(day)
        }
        return count
    }

    func bestStreak() -> Int {
        if rules.frequency == .timesPerWeek { return bestWeekStreak() }

        var best = 0
        var run = 0
        var day = earliestDay
        while day <= today {
            if isScheduled(on: day) {
                if isCompleted(value(on: day)) {
                    run += 1
                    best = max(best, run)
                } else if day < today {
                    run = 0
                }
            }
            day = nextDay(day)
        }
        return best
    }

    private func currentWeekStreak() -> Int {
        var week = weekInterval(containing: today)
        if !weekSucceeded(week) {
            week = weekInterval(containing: previousDay(week.start))
        }
        let firstWeekStart = weekInterval(containing: earliestDay).start
        var count = 0
        while week.start >= firstWeekStart && weekSucceeded(week) {
            count += 1
            week = weekInterval(containing: previousDay(week.start))
        }
        return count
    }

    private func bestWeekStreak() -> Int {
        var best = 0
        var run = 0
        var week = weekInterval(containing: earliestDay)
        while week.start <= today {
            if weekSucceeded(week) {
                run += 1
                best = max(best, run)
            } else if week.end <= today {
                run = 0
            }
            week = weekInterval(containing: week.end)
        }
        return best
    }

    // MARK: - Porcentajes

    /// % de cumplimiento de la semana que contiene `date` (nil si aún no hay nada que medir).
    func weeklyRate(containing date: Date = .now) -> Double? {
        let week = weekInterval(containing: date)
        if rules.frequency == .timesPerWeek {
            guard week.start <= today, rules.timesPerWeek > 0 else { return nil }
            return min(Double(completedDays(in: week)) / Double(rules.timesPerWeek), 1)
        }
        return averageDayScore(in: week)
    }

    /// % de cumplimiento del mes que contiene `date`.
    func monthlyRate(containing date: Date = .now) -> Double? {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return nil }
        if rules.frequency == .timesPerWeek {
            // Semanas que empiezan en este mes y ya terminaron (o ya cumplieron la meta).
            var scores: [Double] = []
            var week = weekInterval(containing: month.start)
            while week.start < month.end && week.start <= today {
                let done = completedDays(in: week)
                let startsInMonth = week.start >= month.start
                if startsInMonth && (week.end <= today || done >= rules.timesPerWeek) && rules.timesPerWeek > 0 {
                    scores.append(min(Double(done) / Double(rules.timesPerWeek), 1))
                }
                week = weekInterval(containing: week.end)
            }
            return scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        }
        return averageDayScore(in: month)
    }

    private func averageDayScore(in interval: DateInterval) -> Double? {
        var total = 0.0
        var count = 0
        var day = interval.start
        while day < interval.end && day <= today {
            if isScheduled(on: day) {
                switch status(on: day) {
                case .completed:
                    total += 1
                    count += 1
                case .partial:
                    total += progress(on: day)
                    count += 1
                case .failed:
                    count += 1
                case .notApplicable, .pending, .future:
                    break
                }
            }
            day = nextDay(day)
        }
        return count == 0 ? nil : total / Double(count)
    }

    // MARK: - Utilidades de fechas

    func weekInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: AppCalendar.startOfDay(date), duration: 7 * 86_400)
    }

    /// Días con la meta cumplida dentro de la semana (hasta hoy).
    func completedDays(in week: DateInterval) -> Int {
        var count = 0
        var day = week.start
        while day < week.end && day <= today {
            if isCompleted(value(on: day)) { count += 1 }
            day = nextDay(day)
        }
        return count
    }

    private func weekSucceeded(_ week: DateInterval) -> Bool {
        completedDays(in: week) >= rules.timesPerWeek
    }

    private func nextDay(_ day: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
    }

    private func previousDay(_ day: Date) -> Date {
        calendar.date(byAdding: .day, value: -1, to: day) ?? day.addingTimeInterval(-86_400)
    }
}

/// Combina el estado de varios hábitos en un día (calendario general).
enum HabitSummary {
    static func combinedStatus(_ evaluators: [HabitEvaluator], on date: Date, today: Date = .now) -> HabitDayStatus {
        let day = AppCalendar.startOfDay(date)
        if day > AppCalendar.startOfDay(today) { return .future }

        let relevant = evaluators
            .map { $0.status(on: day) }
            .filter { $0 != .notApplicable && $0 != .future }
        if relevant.isEmpty { return .notApplicable }
        if relevant.allSatisfy({ $0 == .completed }) { return .completed }

        let hasProgress = relevant.contains { $0 == .completed || $0 == .partial }
        if relevant.contains(.pending) && !hasProgress { return .pending }
        if hasProgress { return .partial }
        return relevant.contains(.failed) ? .failed : .pending
    }
}
