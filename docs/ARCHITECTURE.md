# Architecture

```
Sources/
├── Pocket/main.swift           App entry point (starts AppDelegate)
└── NotchKit/
    ├── Core/                     Pure logic, no AppKit: fully unit-tested
    │   ├── Presentation.swift      Activities, alerts, presentations, priority rules
    │   ├── IslandLayout.swift      Layout engine (real or virtual notch) + the shape outline
    │   ├── IslandMetrics.swift     Every size (mirrors DESIGN.md)
    │   ├── NotchAppearance.swift   User size/style settings and clamping
    │   ├── AlertQueue.swift        One alert at a time, with durations
    │   ├── CountdownTimer.swift    Timer maths with an injected clock
    │   ├── SystemClassifiers.swift Liquid-effect maths
    │   ├── MeetingLinks.swift      Finds Meet, Zoom, Teams and Webex links in events
    │   └── ColorMath.swift         Colour conversions for calendar and reminder tints
    ├── Services/                 System integrations
    │   ├── TimerService            Timer + alarm sound + App Nap guard
    │   ├── TrayStore               Up to 30 session-only references; generated shortcuts cleaned on clear/exit
    │   ├── ClipboardMonitor        Copied text, in memory only; skips private copies
    │   ├── NotesStore              The Notes scratchpad with its formatting (RTF), saved to preferences
    │   ├── TodoStore               The elongated layout's to-do list, saved to preferences
    │   └── CalendarService         EventKit: next event and 5-minute heads-ups
    ├── Island/
    │   ├── IslandModel             Single source of truth: state, gestures, alerts
    │   ├── IslandWindow            Non-activating panel + hosting view
    │   └── IslandWindowController  Display choice, placement, pointer routing, drags
    ├── Views/                    SwiftUI: surface (Canvas), compact, expanded, alerts, home
    ├── Settings/                 Settings store + toolbar-style settings window
    └── App/                      AppDelegate, menu bar item, debug hooks (debug builds only)
```

## Data flow

1. Services publish state (`@Observable`).
2. `IslandModel.presentation` combines that state with user intent (expanded, swiped, hovering,
   dragging) through `PresentationResolver` — a pure function.
3. `LayoutEngine` turns the presentation into geometry for the current display and settings —
   also pure.
4. `IslandRootView` draws the geometry. The surface is `Animatable`, so SwiftUI springs every
   rectangle and radius together; content swaps with a blur transition.
5. `IslandWindowController` feeds pointer positions back into the model and lets the panel take
   the mouse only where the shape is.

## Debug commands

Debug builds listen for a distributed notification named `Pocket.debug`. Its object is a
command: `timer:<seconds>`, `pause`, `cancel`, `home`, `expand`, `collapse`, `drop`, `target`, `nodrop`, `peek`, `hover`, `unhover`, `swipe`,
`settings:<tab>`, `idle`, `dismiss`, `size:<small|medium|large>`, `welcome`,
`dump` (writes the model state to `$TMPDIR/Pocket-debug.txt`), `tray`, `mirror`,
`trayadd:<path>:<path>`, `event`. Example:

```bash
osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSDistributedNotificationCenter.defaultCenter.postNotificationNameObjectUserInfoDeliverImmediately("Pocket.debug", "event", $(), true)'
```
