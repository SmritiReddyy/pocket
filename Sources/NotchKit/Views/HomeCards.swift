import SwiftUI

// Cards beside the widget column on Home: the scratchpad, today's reminders and recent copies.
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
        }
    }
}

/// A soft grey card with a title that opens the feature's own panel.
private struct HomeCardFrame<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: Color
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
        HomeCardFrame(title: "Reminders", symbol: "checklist", tint: NotchColor.blue) {
            model.open(.reminders)
        } content: {
            switch reminders.access {
            case .notAsked:
                prompt("See today's to-dos here.", button: "Connect") { reminders.requestAccess() }
            case .denied:
                prompt("Reminders access is off.", button: "Open Settings") { reminders.openPrivacySettings() }
            case .granted:
                if reminders.items.isEmpty {
                    Text("Nothing left for today")
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
