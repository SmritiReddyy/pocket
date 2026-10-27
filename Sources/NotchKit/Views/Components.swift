import AppKit
import SwiftUI

struct AppIconView: View {
    var icon: NSImage?
    var symbol: String
    var tint: Color
    var size: CGFloat

    var body: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
    }
}

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

/// iOS-style battery: outlined body, fill by level, cap, and a bolt while charging.
struct BatteryGlyph: View {
    var level: Int
    var isCharging: Bool
    var color: Color
    var width: CGFloat = 27

    var body: some View {
        let height = width * 0.48
        let inset = width * 0.075
        HStack(spacing: width * 0.04) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height * 0.3, style: .continuous)
                    .strokeBorder(color.opacity(0.45), lineWidth: 1)
                RoundedRectangle(cornerRadius: height * 0.18, style: .continuous)
                    .fill(color)
                    .frame(width: max(2, (width - inset * 2) * CGFloat(min(max(level, 0), 100)) / 100))
                    .padding(inset)
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: height * 0.72, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 0.5)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: width, height: height)
            Capsule()
                .fill(color.opacity(0.45))
                .frame(width: width * 0.06, height: height * 0.36)
        }
        .accessibilityHidden(true)
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
