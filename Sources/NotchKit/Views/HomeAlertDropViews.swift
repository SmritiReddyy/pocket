import SwiftUI
import UniformTypeIdentifiers

// MARK: Alerts

struct AlertView: View {
    let model: IslandModel
    let alert: IslandAlert
    /// Middle width kept clear for the camera.
    var cameraGap: CGFloat = 0
    @Environment(\.notchScale) private var s

    var body: some View {
        switch alert {
        case .timerFinished:
            TimerFinishedView(model: model)
        case .welcome:
            AlertRow(cameraGap: cameraGap) {
                Text(Greeting.text(fullName: NSFullUserName()))
                    .truncationMode(.tail)
            } trailing: {
                WavingHand()
            }
            .accessibilityElement(children: .combine)
        case .upcomingEvent(let title, let minutes):
            AlertRow(cameraGap: cameraGap) {
                HStack(spacing: 6 * s) {
                    Image(systemName: "calendar")
                        .foregroundStyle(NotchColor.red)
                    Text(title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } trailing: {
                Text(minutes <= 0 ? "Starting now" : "In \(minutes) min")
                    .foregroundStyle(NotchColor.red)
            }
            .accessibilityElement(children: .combine)
        case .updateAvailable(let version):
            AlertRow(cameraGap: cameraGap) {
                HStack(spacing: 6 * s) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(NotchColor.blue)
                    Text("Update")
                }
            } trailing: {
                Text("Version \(version)")
                    .foregroundStyle(NotchColor.blue)
            }
            .help("Click to see what's new and install it")
            .accessibilityElement(children: .combine)
        }
    }

}

/// Leading content left of the camera, trailing content right of it.
private struct AlertRow<Leading: View, Trailing: View>: View {
    var cameraGap: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @Environment(\.notchScale) private var s

    var body: some View {
        GeometryReader { geometry in
            let edge: CGFloat = (cameraGap > 0 ? 14 : 20) * s
            let side = max(0, (geometry.size.width - cameraGap) / 2 - edge - (cameraGap > 0 ? 6 : 4))
            HStack(spacing: 0) {
                leading
                    .frame(width: side, alignment: .leading)
                Spacer(minLength: 0)
                trailing
                    .frame(width: side, alignment: .trailing)
            }
            .padding(.horizontal, edge)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .font(.system(size: 14 * s, weight: .semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
    }
}

private struct WavingHand: View {
    @Environment(\.notchScale) private var s
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: "\u{1F44B}")
            .font(.system(size: 17 * s))
            .phaseAnimator(reduceMotion ? [0.0] : [0.0, 20, -8, 20, -8, 14, 0, 0, 0]) { hand, angle in
                hand.rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.7, y: 0.85))
            } animation: { _ in
                .easeInOut(duration: 0.16)
            }
            .accessibilityHidden(true)
    }
}

private struct TimerFinishedView: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    private static func headline(_ mode: TimerMode) -> LocalizedStringKey {
        switch mode {
        case .plain: "Done"
        case .focus: "Take a break"
        case .rest: "Back to it"
        }
    }

    var body: some View {
        let mode = model.timer.timer?.mode ?? .plain
        HStack(spacing: 12 * s) {
            Image(systemName: "bell.fill")
                .font(.system(size: 24 * s, weight: .semibold))
                .foregroundStyle(mode.tint)
                .phaseAnimator([0.0, -16, 14, -10, 8, 0, 0, 0]) { bell, angle in
                    bell.rotationEffect(.degrees(angle), anchor: .top)
                } animation: { _ in
                    .easeInOut(duration: 0.11)
                }
                .frame(width: 44 * s)
            VStack(alignment: .leading, spacing: 0) {
                Text(mode.title)
                    .font(.system(size: 13 * s, weight: .semibold))
                    .foregroundStyle(mode.tint)
                Text(Self.headline(mode))
                    .font(.system(size: 26 * s, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8 * s)
            if let next = mode.next {
                // Focus offers the break, and the break offers the next focus session.
                CircleButton(symbol: next.symbol, size: 48 * s, foreground: next.tint, background: next.tint.opacity(0.25), label: next == .rest ? "Start Break" : "Focus Again") {
                    model.startSession(next)
                }
            } else {
                CircleButton(symbol: "arrow.counterclockwise", size: 48 * s, label: "Repeat Timer") { model.repeatTimer() }
            }
            CircleButton(symbol: "xmark", size: 48 * s, foreground: .black, background: mode.tint, label: "Stop Timer") {
                model.stopTimerAlarm()
            }
        }
        .padding(.horizontal, 20 * s)
    }
}

// MARK: Drop

struct DropView: View {
    let model: IslandModel
    let isTargeted: Bool
    @Environment(\.notchScale) private var s

    var body: some View {
        Group {
            if model.settings.trayEnabled {
                TrayDropZone(model: model, isTargeted: model.targetedZone == .tray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12 * s)
        .animation(.spring(duration: 0.3, bounce: 0.35), value: model.targetedZone)
    }
}

/// A dashed blue box with the files already in Tray peeking out on the right.
private struct TrayDropZone: View {
    let model: IslandModel
    let isTargeted: Bool
    @Environment(\.notchScale) private var s

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20 * s, style: .continuous)
        HStack(alignment: .center, spacing: 8 * s) {
            VStack(alignment: .leading, spacing: 6 * s) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 17 * s, weight: .semibold))
                Text(isTargeted ? "Keep in Tray" : "Files Tray")
                    .font(.system(size: 12 * s, weight: .semibold))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(NotchColor.blue)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.bottom, 4 * s)
            TrayPeek(model: model)
        }
        .padding(14 * s)
        .background(shape.fill(NotchColor.blue.opacity(isTargeted ? 0.14 : 0.04)))
        .overlay(shape.strokeBorder(NotchColor.blue.opacity(isTargeted ? 1 : 0.6), style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [7, 5])))
        .scaleEffect(isTargeted ? 1.02 : 1)
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Files Tray"))
    }
}

/// Up to four of the newest Tray files, as small icons in a square.
private struct TrayPeek: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        // The Tray keeps the newest first.
        let items = Array(model.tray.items.prefix(4))
        let size = 24 * s
        if !items.isEmpty {
            LazyVGrid(columns: [GridItem(.fixed(size), spacing: 5 * s), GridItem(.fixed(size), spacing: 5 * s)], spacing: 5 * s) {
                ForEach(items) { item in
                    Image(nsImage: model.tray.icon(for: item))
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                }
            }
            .frame(width: size * 2 + 5 * s)
            .accessibilityHidden(true)
        }
    }
}
