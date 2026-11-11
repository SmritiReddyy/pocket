import SwiftUI

// Cards beside the widget column on Home: the scratchpad, today's reminders, recent copies and
// a camera mirror.
// Each one works right where it is, and its title opens the full panel.

/// The card for one Home feature.
struct HomeCardView: View {
    let model: IslandModel
    let card: HomeCard

    var body: some View {
        switch card {
        case .notes: NotesHomeCard(model: model)
        case .reminders: RemindersHomeCard(model: model)
        case .clipboard: ClipboardHomeCard(model: model)
        case .mirror: MirrorHomeCard(model: model)
        }
    }
}

/// A soft grey card with a title that opens the feature's own panel, and room for a control
/// on the right of the title.
private struct HomeCardFrame<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
    var accessory: AnyView?
    let open: () -> Void
    @ViewBuilder var content: Content
    @State private var isHovering = false
    @Environment(\.notchScale) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            Button(action: open) {
                HStack(spacing: 5 * s) {
                    Image(systemName: symbol)
                        .font(.system(size: 10 * s, weight: .bold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.system(size: 11 * s, weight: .semibold))
                        .foregroundStyle(.white.opacity(isHovering ? 1 : 0.85))
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 8 * s, weight: .bold))
                        .foregroundStyle(Color.white.opacity(isHovering ? 0.6 : 0.3))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle())
            .onHover { isHovering = $0 }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .trailing) { accessory }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 10 * s)
        .padding(.vertical, 8 * s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14 * s, style: .continuous).fill(Color.white.opacity(0.07)))
    }
}

// MARK: Scratchpad

/// The Notes scratchpad, typed into right on Home. Same note as the Notes panel.
private struct NotesHomeCard: View {
    let model: IslandModel
    @State private var controller = RichTextController()
    @Environment(\.notchScale) private var s

    var body: some View {
        NoteCard(model: model, controller: controller, fontSize: 12 * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: Reminders

/// Today's to-dos. Tick one off with its circle.
private struct RemindersHomeCard: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        let reminders = model.reminders
        HomeCardFrame(
            title: "Reminders", symbol: "checklist", tint: NotchColor.blue,
            accessory: reminders.access == .granted ? AnyView(ReminderListMenu(model: model, compact: true)) : nil
        ) {
            model.open(.reminders)
        } content: {
            switch reminders.access {
            case .notAsked:
                prompt("See today's to-dos here.", button: "Connect") { reminders.requestAccess() }
            case .denied:
                prompt("Reminders access is off.", button: "Open Settings") { reminders.openPrivacySettings() }
            case .granted:
                if reminders.items.isEmpty {
                    Text(ReminderListMenu.emptyText(reminders.selectedList))
                        .font(.system(size: 11 * s, weight: .medium))
                        .foregroundStyle(NotchColor.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(reminders.items) { item in
                                ReminderRow(item: item, fontSize: 11.5) {
                                    withAnimation(.spring(duration: 0.35, bounce: 0.2)) { reminders.complete(item) }
                                    Haptics.perform(enabled: model.settings.hapticsEnabled)
                                }
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                    }
                }
            }
        }
    }

    private func prompt(_ text: LocalizedStringKey, button: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6 * s) {
            Text(text)
                .font(.system(size: 11 * s, weight: .medium))
                .foregroundStyle(NotchColor.secondaryText)
            Button(button, action: action)
                .buttonStyle(ChipButtonStyle(tint: NotchColor.blue, scale: s))
                .fixedSize()
        }
    }
}

// MARK: Mirror

/// A quick look at the camera. It only turns on when you click it, and goes off again when the
/// notch closes, so opening Home never lights up the camera by itself.
private struct MirrorHomeCard: View {
    let model: IslandModel
    @State private var isOn = false
    @State private var isHovering = false
    @Environment(\.notchScale) private var s

    var body: some View {
        let camera = model.camera
        HomeCardFrame(title: "Mirror", symbol: "web.camera", tint: NotchColor.blue) {
            model.open(.mirror)
        } content: {
            let shape = RoundedRectangle(cornerRadius: 10 * s, style: .continuous)
            Button {
                switch camera.state {
                case .granted: withAnimation(.smooth(duration: 0.3)) { isOn.toggle() }
                case .notAsked: camera.request()
                case .denied: camera.openPrivacySettings()
                case .noCamera: break
                }
            } label: {
                ZStack {
                    shape.fill(Color.white.opacity(isHovering ? 0.1 : 0.05))
                    if isOn, camera.state == .granted {
                        CameraPreview()
                            .clipShape(shape)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        VStack(spacing: 4 * s) {
                            Image(systemName: Self.symbol(camera.state))
                                .font(.system(size: 16 * s, weight: .regular))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(Self.prompt(camera.state))
                                .font(.system(size: 10 * s, weight: .medium))
                                .foregroundStyle(NotchColor.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 4 * s)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(shape)
                .animation(.easeOut(duration: 0.15), value: isHovering)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(camera.state == .noCamera)
            .onHover { isHovering = $0 }
            .onAppear { camera.refresh() }
            .help(isOn ? "Turn off the camera" : "Check how you look")
            .accessibilityLabel(Text(isOn ? "Turn off the camera" : "Camera Mirror"))
        }
    }

    private static func symbol(_ state: CameraAccess.State) -> String {
        switch state {
        case .noCamera: "video.slash"
        case .denied: "lock.fill"
        default: "camera.fill"
        }
    }

    private static func prompt(_ state: CameraAccess.State) -> LocalizedStringKey {
        switch state {
        case .granted: "Click to look"
        case .notAsked: "Click to allow the camera"
        case .denied: "Camera is off. Click to allow"
        case .noCamera: "No camera"
        }
    }
}

// MARK: Clipboard

/// The last few things copied. Click one to copy it again.
private struct ClipboardHomeCard: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        let entries = model.clipboard.history.entries
        HomeCardFrame(title: "Clipboard", symbol: "doc.on.clipboard.fill", tint: NotchColor.orange) {
            model.open(.clipboard)
        } content: {
            if entries.isEmpty {
                Text("Text you copy shows up here")
                    .font(.system(size: 11 * s, weight: .medium))
                    .foregroundStyle(NotchColor.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 3 * s) {
                    ForEach(entries.prefix(3)) { entry in
                        ClipboardLine(model: model, entry: entry)
                    }
                }
            }
        }
    }
}

private struct ClipboardLine: View {
    let model: IslandModel
    let entry: ClipboardHistory.Entry
    @State private var isHovering = false
    @Environment(\.notchScale) private var s

    var body: some View {
        let copied = model.clipboard.justCopied == entry.id
        Button {
            model.clipboard.copy(entry)
        } label: {
            HStack(spacing: 5 * s) {
                Text(ClipboardHistory.preview(entry.text, limit: 80))
                    .font(.system(size: 11.5 * s, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if copied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9 * s, weight: .bold))
                        .foregroundStyle(NotchColor.green)
                }
            }
            .padding(.horizontal, 6 * s)
            .frame(height: 22 * s)
            .background(
                RoundedRectangle(cornerRadius: 7 * s, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.12 : 0.05))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .onHover { isHovering = $0 }
        .help("Click to copy")
        .accessibilityLabel(Text("Copy \(ClipboardHistory.preview(entry.text, limit: 60))"))
    }
}
