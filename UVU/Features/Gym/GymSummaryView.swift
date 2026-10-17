import Charts
import SwiftUI

/// Vista "Resumen" del Gym: reparto por grupo muscular (gráfico de torta y porcentajes) del mes o
/// del año acumulado, comparación con el periodo anterior, récords del periodo y series por mes.
/// Cada serie hecha cuenta 1 para el músculo principal del ejercicio.
struct GymSummarySections: View {
    let sessions: [WorkoutSession]
    let unit: WeightUnit

    @State private var period: SummaryPeriod = .month
    @State private var anchor = Date.now

    var body: some View {
        let sets = TrainingSummary.sets(from: sessions, unit: unit)
        let shares = TrainingSummary.shares(sets, period: period, containing: anchor)
        let total = TrainingSummary.totalSets(sets, period: period, containing: anchor)
        let progress = TrainingSummary.progress(sets, period: period, containing: anchor)
        let months = TrainingSummary.monthlyTotals(sets, year: anchor)

        Section {
            ScopeBar(options: SummaryPeriod.allCases, selection: $period, title: \.title)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: 0, trailing: Space.m))
            PeriodHeader(title: periodTitle, canGoForward: canGoForward) { shift(by: $0) }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: 0, trailing: Space.m))
        }

        Section {
            if total == 0 {
                Text(period == .month ? "Sin series este mes." : "Sin series este año.")
                    .labelCaps(12, .semibold)
                    .padding(.vertical, Space.s)
            } else {
                MuscleDonut(shares: shares.filter { $0.sets > 0 }, total: total)
                    .frame(height: 240)
                    .padding(.vertical, Space.s)
            }
            ForEach(shares) { share in
                MuscleShareRow(share: share, comparison: comparisonLabel)
            }
        } header: {
            Text("Grupos musculares").labelCaps()
        } footer: {
            Text("Cada serie hecha cuenta 1 para el músculo principal del ejercicio. El mes empieza de cero cada día 1; el año suma todos sus meses.")
                .formFooter()
        }
        .rowSurface()

        Section {
            if progress.isEmpty {
                Text(period == .month ? "Sin récords este mes. Todavía." : "Sin récords este año. Todavía.")
                    .labelCaps(12, .semibold)
                    .padding(.vertical, Space.xxs)
            }
            ForEach(progress) { item in
                ProgressRow(item: item, unit: unit)
            }
        } header: {
            Text(period == .month ? "Récords del mes" : "Récords del año").labelCaps()
        } footer: {
            Text("Ejercicios en los que superaste tu mejor peso o tu 1RM estimado de antes.")
                .formFooter()
        }
        .rowSurface()

        Section {
            YearBars(months: months, highlighted: period == .month ? anchor : nil)
                .frame(height: 180)
                .padding(.vertical, Space.s)
        } header: {
            Text("Series por mes · \(yearTitle)").labelCaps()
        }
        .rowSurface()
    }

    // MARK: - Periodo

    private var periodTitle: String {
        switch period {
        case .month: return anchor.formatted(.dateTime.month(.wide).year().locale(AppLocale.spanish))
        case .year: return yearTitle
        }
    }

    private var yearTitle: String {
        String(AppCalendar.calendar.component(.year, from: anchor))
    }

    private var comparisonLabel: String {
        period == .month ? "vs mes anterior" : "vs año anterior"
    }

    private var canGoForward: Bool {
        TrainingSummary.interval(period, containing: anchor).end <= .now
    }

    private func shift(by value: Int) {
        guard let next = AppCalendar.calendar.date(byAdding: period.component, value: value, to: anchor) else { return }
        withAnimation(Motion.quick) { anchor = min(next, .now) }
    }
}

extension MuscleGroup {
    /// Color fijo de cada grupo (el mismo cada mes), dentro de la paleta DISCIPLINE.
    var chartColor: Color {
        switch self {
        case .chest: return .signal
        case .back: return .bone
        case .legs: return .brass
        case .glutes: return .signalDeep
        case .shoulders: return .ash
        case .biceps: return Color.bone.opacity(0.55)
        case .triceps: return Color.brass.opacity(0.55)
        case .core: return Color.ash.opacity(0.5)
        case .cardio: return .graphite
        case .other: return Color.signal.opacity(0.45)
        }
    }
}

// MARK: - Piezas

/// Título del periodo con flechas para ir al anterior o al siguiente.
private struct PeriodHeader: View {
    let title: String
    let canGoForward: Bool
    var onShift: (Int) -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.display(26, relativeTo: .title2))
                .textCase(.uppercase)
                .foregroundStyle(.bone)
            Spacer()
            Button {
                onShift(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Periodo anterior")
            Button {
                onShift(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 40, height: 40)
            }
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.3)
            .accessibilityLabel("Periodo siguiente")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.bone)
    }
}

/// Gráfico de torta (anillo) con el total de series en el centro.
private struct MuscleDonut: View {
    let shares: [MuscleShare]
    let total: Int

    var body: some View {
        Chart(shares) { share in
            SectorMark(angle: .value("Series", share.sets), innerRadius: .ratio(0.62), angularInset: 1.5)
                .foregroundStyle(share.muscle.chartColor)
                .cornerRadius(2)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in
            VStack(spacing: 0) {
                Text("\(total)")
                    .font(.numeral(48))
                    .monospacedDigit()
                    .foregroundStyle(.bone)
                Text(total == 1 ? "serie" : "series").labelCaps(11, .semibold)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(shares.map { "\($0.muscle.title) \(Self.percent($0.fraction))" }.joined(separator: ", "))
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) %"
    }
}

/// Fila de un grupo: color, nombre, barra, porcentaje, series y cambio frente al periodo anterior.
private struct MuscleShareRow: View {
    let share: MuscleShare
    let comparison: String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                    .fill(share.muscle.chartColor)
                    .frame(width: 12, height: 12)
                Text(share.muscle.title)
                    .font(.ui(15, .semibold, relativeTo: .subheadline))
                    .textCase(.uppercase)
                    .foregroundStyle(.bone)
                Spacer(minLength: Space.xs)
                Text(MuscleDonut.percent(share.fraction))
                    .font(.numeral(22, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(.bone)
            }
            QuantityBar(progress: share.fraction)
            HStack(spacing: Space.xs) {
                Text("\(share.sets) \(share.sets == 1 ? "serie" : "series")")
                Spacer()
                Text(changeText)
            }
            .labelCaps(10, .semibold)
            .monospacedDigit()
        }
        .padding(.vertical, Space.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(share.muscle.title), \(MuscleDonut.percent(share.fraction)), \(share.sets) series, \(changeText)")
    }

    private var changeText: String {
        guard let change = share.change else {
            // Sin datos del periodo anterior no hay con qué comparar.
            return ""
        }
        let value = Int((abs(change) * 100).rounded())
        if value == 0 { return "= \(comparison)" }
        return "\(change > 0 ? "▲" : "▼") \(value) % \(comparison)"
    }
}

/// Récord de un ejercicio en el periodo: cuánto subió el peso máximo y el 1RM.
private struct ProgressRow: View {
    let item: ExerciseProgress
    let unit: WeightUnit

    var body: some View {
        HStack(alignment: .center, spacing: Space.s) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(item.name)
                    .font(.ui(15, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(.bone)
                Text(item.muscle.title).labelCaps(10, .semibold)
            }
            Spacer(minLength: Space.xs)
            VStack(alignment: .trailing, spacing: Space.xxs) {
                if let gain = item.weightGain {
                    gainLabel("Peso", value: item.bestWeight, gain: gain)
                }
                if let gain = item.oneRepMaxGain {
                    gainLabel("1RM", value: item.bestOneRepMax, gain: gain)
                }
            }
        }
        .padding(.vertical, Space.xxs)
        .accessibilityElement(children: .combine)
    }

    private func gainLabel(_ title: String, value: Double, gain: Double) -> some View {
        HStack(spacing: Space.xs) {
            Text(title).labelCaps(10, .semibold)
            Text(GymMath.format(value, unit: unit))
                .font(.ui(13, .semibold))
                .monospacedDigit()
                .foregroundStyle(.bone)
            Text("+\(GymMath.format(gain, unit: unit))")
                .font(.ui(12, .black))
                .monospacedDigit()
                .foregroundStyle(.brass)
        }
    }
}

/// Barras de series por mes del año; el mes elegido va en rojo.
private struct YearBars: View {
    let months: [MonthTotal]
    let highlighted: Date?

    var body: some View {
        Chart(months) { total in
            BarMark(x: .value("Mes", total.month, unit: .month), y: .value("Series", total.sets))
                .foregroundStyle(isHighlighted(total.month) ? Color.signal : .bone)
                .cornerRadius(2)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.narrow).locale(AppLocale.spanish)))
                            .foregroundStyle(Color.ash)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.graphite)
                AxisValueLabel().foregroundStyle(Color.ash)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(months.filter { $0.sets > 0 }.map {
            "\($0.month.formatted(.dateTime.month(.wide).locale(AppLocale.spanish))): \($0.sets) series"
        }.joined(separator: ", "))
    }

    private func isHighlighted(_ month: Date) -> Bool {
        guard let highlighted else { return false }
        return AppCalendar.calendar.isDate(month, equalTo: highlighted, toGranularity: .month)
    }
}
