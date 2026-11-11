import AppKit
import SwiftUI

/// Scales down slightly while pressed, like iOS controls.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// Round control from the iPhone timer and call activities.
struct CircleButton: View {
    var symbol: String
    var size: CGFloat = 44
    var foreground: Color = .white
    var background: Color = NotchColor.buttonFill
    var label: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(label))
    }
}

/// Plain glyph button for transport controls.
struct GlyphButton: View {
    var symbol: String
    var size: CGFloat
    var label: LocalizedStringKey
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size * 1.8, height: size * 1.6)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(label))
    }
}

struct ChipButtonStyle: ButtonStyle {
    var tint: Color = NotchColor.orange
    var scale: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12 * scale, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(tint)
            .padding(.horizontal, 4 * scale)
            .frame(height: 30 * scale)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(tint.opacity(configuration.isPressed ? 0.32 : 0.18)))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

/// A countdown that ticks on its own, like Live Activities.
struct CountdownText: View {
    var timer: CountdownTimer

    var body: some View {
        if let end = timer.endDate {
            let now = Date()
            Text(timerInterval: min(now, end)...end, countsDown: true)
        } else {
            Text(TimeFormatting.clock(timer.remaining(at: Date()), roundingUp: true))
        }
    }
}
