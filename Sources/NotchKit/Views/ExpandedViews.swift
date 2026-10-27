import SwiftUI

// All sizes below are the Large design; `notchScale` shrinks them for Medium and Small.

// MARK: Call

struct CallExpandedView: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        if let session = model.calls.session {
            let tint = session.isCall ? NotchColor.green : NotchColor.orange
            HStack(spacing: 12 * s) {
                AppIconView(icon: model.calls.appIcon, symbol: session.isCall ? "phone.fill" : "mic.fill", tint: tint, size: 46 * s)
                VStack(alignment: .leading, spacing: 2 * s) {
                    Text(session.appName)
                        .font(.system(size: 15 * s, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    HStack(spacing: 6 * s) {
                        Text(session.isCall ? "On Call" : "Using Microphone")
                        Text(session.startDate, style: .timer)
                            .monospacedDigit()
                    }
                    .font(.system(size: 13 * s))
                    .foregroundStyle(NotchColor.secondaryText)
                    .lineLimit(1)
                }
                Spacer(minLength: 8 * s)
                if session.usesCamera {
                    Image(systemName: "video.fill")
                        .font(.system(size: 12 * s, weight: .semibold))
                        .foregroundStyle(NotchColor.green)
                        .accessibilityLabel(Text("Camera in use"))
                }
                // Mutes the Mac's microphone, so it works whatever app the call is in.
                if model.microphone.canMute {
                    let muted = model.microphone.isMuted
                    CircleButton(
                        symbol: muted ? "mic.slash.fill" : "mic.fill",
                        size: 44 * s,
                        foreground: muted ? .white : NotchColor.orange,
                        background: muted ? NotchColor.red : NotchColor.orange.opacity(0.22),
                        label: muted ? "Unmute Microphone" : "Mute Microphone"
                    ) { model.microphone.toggle() }
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 12 * s, weight: .semibold))
                        .foregroundStyle(NotchColor.orange)
                        .accessibilityLabel(Text("Microphone in use"))
                }
                CircleButton(symbol: "arrow.up.forward", size: 44 * s, foreground: .white, background: tint, label: "Show \(session.appName)") {
                    model.calls.showApp()
                    model.collapse()
                }
            }
            .padding(.horizontal, 20 * s)
        }
    }
}
