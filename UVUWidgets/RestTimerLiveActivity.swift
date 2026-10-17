import ActivityKit
import SwiftUI
import WidgetKit

/// Colores DISCIPLINE (la extensión no comparte el Asset Catalog de la app).
private enum Palette {
    static let ink = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let bone = Color(red: 233 / 255, green: 227 / 255, blue: 214 / 255)
    static let ash = Color(red: 140 / 255, green: 140 / 255, blue: 140 / 255)
    static let signal = Color(red: 212 / 255, green: 42 / 255, blue: 32 / 255)
}

/// Cuenta atrás del descanso en la pantalla de bloqueo y en la Dynamic Island.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            LockScreenRestView(context: context)
                .activityBackgroundTint(Palette.ink)
                .activitySystemActionForegroundColor(Palette.signal)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DESCANSO")
                            .font(.system(size: 12, weight: .black))
                            .tracking(1.5)
                            .foregroundStyle(Palette.signal)
                        Text(context.state.exerciseName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.bone)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state, size: 34)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.workoutName.uppercased()) · \(context.state.nextSet.uppercased())")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(Palette.ash)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.signal)
            } compactTrailing: {
                countdown(context.state, size: 14)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.signal)
            }
            .keylineTint(Palette.signal)
        }
    }

    private func countdown(_ state: RestActivityAttributes.ContentState, size: CGFloat) -> some View {
        Text(timerInterval: state.startDate...max(state.endDate, state.startDate), countsDown: true)
            .font(.system(size: size, weight: .light).monospacedDigit())
            .foregroundStyle(Palette.signal)
            .multilineTextAlignment(.trailing)
    }
}

/// Vista de la pantalla de bloqueo: como el temporizador del iPhone, en estilo DISCIPLINE.
private struct LockScreenRestView: View {
    let context: ActivityViewContext<RestActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DESCANSO")
                    .font(.system(size: 13, weight: .black))
                    .tracking(1.8)
                    .foregroundStyle(Palette.signal)
                Text(context.state.exerciseName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.bone)
                    .lineLimit(1)
                Text("\(context.attributes.workoutName) · \(context.state.nextSet)".uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.ash)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(timerInterval: context.state.startDate...max(context.state.endDate, context.state.startDate),
                 countsDown: true)
                .font(.system(size: 46, weight: .light).monospacedDigit())
                .foregroundStyle(Palette.signal)
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 110, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}
