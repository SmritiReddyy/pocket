import AppKit
import EventKit
import Foundation
import Testing
@testable import NotchKit

@Suite("Calendar polish")
struct CalendarPolishTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    @Test func allDayEventsLeadTheirDayAndNeverRing() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 9))!
        let dayStart = calendar.startOfDay(for: now)
        let allDay = CalendarEvent(id: "a", title: "Holiday", start: dayStart, end: dayStart.addingTimeInterval(86400), isAllDay: true)
        let meeting = CalendarEvent(id: "m", title: "Standup", start: now.addingTimeInterval(1800), end: now.addingTimeInterval(3600))
        #expect(CalendarRules.upcoming(in: [meeting, allDay], at: now, limit: 3).map(\.id) == ["a", "m"])
        #expect(CalendarRules.nextEvent(in: [allDay, meeting], at: now)?.id == "m")
        #expect(CalendarRules.nextReminder(in: [allDay], after: now, reminded: []) == nil)
        #expect(CalendarRules.timeRange(for: allDay, at: now) == "All day")
    }

    @Test func laterDaysSayWhichDay() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 20))!
        let tomorrow = CalendarEvent(id: "t", title: "Review", start: now.addingTimeInterval(14 * 3600), end: now.addingTimeInterval(15 * 3600))
        #expect(CalendarRules.dayLabel(for: tomorrow, at: now, calendar: calendar) == "Tomorrow")
        #expect(CalendarRules.relativeLabel(for: tomorrow, at: now, calendar: calendar).hasPrefix("Tomorrow "))
        let today = CalendarEvent(id: "n", title: "Now", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(600))
        #expect(CalendarRules.dayLabel(for: today, at: now, calendar: calendar) == "Today")
    }

    @Test func allowingAccessCountsEvenBeforeMacOSCatchesUp() {
        // Right after the user allows access, macOS can still say "not asked yet".
        #expect(CalendarService.access(for: .notDetermined, grantedThisSession: true) == .granted)
        #expect(CalendarService.access(for: .notDetermined, grantedThisSession: false) == .notAsked)
        #expect(CalendarService.access(for: .fullAccess, grantedThisSession: false) == .granted)
        #expect(CalendarService.access(for: .writeOnly, grantedThisSession: true) == .limited)
        #expect(CalendarService.access(for: .denied, grantedThisSession: true) == .denied)
        #expect(RemindersService.access(for: .notDetermined, grantedThisSession: true) == .granted)
        #expect(RemindersService.access(for: .notDetermined, grantedThisSession: false) == .notAsked)
    }
}

@MainActor
@Suite("Hover to open")
struct HoverOpenTests {
    private func makeModel() -> IslandModel {
        let defaults = UserDefaults(suiteName: "NotchTests-\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
        model.settings.notchOpenMode = .hover
        return model
    }

    @Test(arguments: NotchSize.allCases)
    func theRestingPillOpensHome(size: NotchSize) async throws {
        let model = makeModel()
        model.settings.appearance.size = size
        model.isPreviewing = true
        #expect(model.presentation == .idle)
        let center = CGPoint(x: model.layout.pill.midX, y: model.layout.pill.midY)
        model.pointerMoved(to: center)
        for _ in 0..<60 where model.presentation != .home {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(model.presentation == .home)
    }

    @Test(arguments: NotchSize.allCases)
    func theNotchOpensHomeFromItsEdge(size: NotchSize) async throws {
        let model = makeModel()
        model.settings.appearance.size = size
        let notch = model.engine.notchInWindow
        // Just past the camera housing, on the peek it swells into.
        model.pointerMoved(to: CGPoint(x: notch.maxX + 6, y: 10))
        for _ in 0..<60 where model.presentation != .home {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(model.presentation == .home)
    }
}

@Suite("Display choice")
struct DisplayChoiceTests {
    @Test func survivesSavingAndLoading() {
        for choice: DisplayChoice in [.automatic, .main, .followPointer, .all, .specific("37D8832A-2D66-02CA-B9F7-8F30A301B230")] {
            #expect(DisplayChoice(rawValue: choice.rawValue) == choice)
        }
        #expect(DisplayChoice(rawValue: "display:") == nil)
        #expect(DisplayChoice(rawValue: "moon") == nil)
    }
}

@MainActor
@Suite("All displays")
struct AllDisplaysTests {
    private func makeModel() -> IslandModel {
        let defaults = UserDefaults(suiteName: "NotchTests-\(UUID().uuidString)")!
        return IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil), notes: NotesStore(defaults: defaults))
    }

    private let external = ScreenMetrics(size: CGSize(width: 2560, height: 1440), notch: nil, menuBarHeight: 25)

    @Test func openedThingsShowOnlyOnTheScreenInUse() {
        let model = makeModel()
        model.useOnly(display: 1, metrics: .sample)
        model.timer.start(duration: 300)
        model.expand(.home)
        #expect(model.presentation(onDisplay: 1) == .home)
        #expect(model.presentation(onDisplay: 2) == .compact(primary: .timer, secondary: nil))
        #expect(model.layout(onDisplay: 2, metrics: external).flare > 0, "no notch: still a notch")
        model.cancelTimer()
    }

    @Test func switchesScreensOnlyWhenNothingIsOpen() {
        let model = makeModel()
        model.useOnly(display: 1, metrics: .sample)
        model.expand(.home)
        #expect(!model.activate(display: 2, metrics: external))
        #expect(model.activeDisplayID == 1)
        model.collapse()
        #expect(model.activate(display: 2, metrics: external))
        #expect(model.activeDisplayID == 2)
        #expect(model.screen == external)
    }
}

@Suite("Elongated layout")
struct ElongatedLayoutTests {
    private func engine(_ layout: NookLayout, screen: ScreenMetrics = .sample) -> LayoutEngine {
        var appearance = NotchAppearance.standard
        appearance.nookLayout = layout
        return LayoutEngine(screen: screen, appearance: appearance)
    }

    @Test func homeAndItsTabsStretchAcrossTheTop() {
        let standard = engine(.standard), elongated = engine(.elongated)
        for presentation in [IslandPresentation.home, .tray, .clipboard] {
            let wide = elongated.layout(for: presentation, home: HomeContent(), hovering: false)
            #expect(wide.pill.width > standard.layout(for: presentation, home: HomeContent(), hovering: false).pill.width + 400)
            #expect(wide.pill.minX >= IslandMetrics.Nook.elongatedEdge - 1)
            #expect(wide.pill.maxX <= ScreenMetrics.sample.size.width - IslandMetrics.Nook.elongatedEdge + 1)
            #expect(wide.pill.minY == 0)
        }
    }

    @Test func panelsKeepTheirOwnSize() {
        for presentation in [IslandPresentation.nook(.launcher), .nook(.calendar), .nook(.timers), .expanded(.timer)] {
            #expect(engine(.elongated).layout(for: presentation, home: HomeContent(), hovering: false).pill
                == engine(.standard).layout(for: presentation, home: HomeContent(), hovering: false).pill)
        }
    }

    @Test func fitsAnExternalScreenToo() {
        let external = ScreenMetrics(size: CGSize(width: 2560, height: 1440), notch: nil, menuBarHeight: 25)
        let elongated = engine(.elongated, screen: external)
        let home = elongated.layout(for: .home, home: HomeContent(), hovering: false)
        #expect(home.pill.width <= IslandMetrics.Nook.elongatedMaxWidth + 2 * IslandMetrics.expandedFlare)
        #expect(abs(home.pill.midX - external.size.width / 2) < 1)
        #expect(home.pill.maxY <= elongated.windowSize.height)
    }

    @MainActor
    @Test func layoutChoicePersists() {
        let defaults = UserDefaults(suiteName: "NotchTests-\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        #expect(store.appearance.nookLayout == .standard)
        store.appearance.nookLayout = .elongated
        #expect(SettingsStore(defaults: defaults).appearance.nookLayout == .elongated)
    }
}

@Suite("Meeting links")
struct MeetingLinkTests {
    @Test func findsTheCallInAnEvent() throws {
        let meet = try #require(MeetingLinks.joinLink(in: [nil, "Room 4", "Join: https://meet.google.com/abc-defg-hij"]))
        #expect(meet.provider == .meet && meet.url.host == "meet.google.com")
        #expect(MeetingLinks.joinLink(in: ["https://us02web.zoom.us/j/123456789?pwd=x"])?.provider == .zoom)
        #expect(MeetingLinks.joinLink(in: ["https://teams.microsoft.com/l/meetup-join/19%3ameeting_x"])?.provider == .teams)
        #expect(MeetingLinks.joinLink(in: ["https://acme.webex.com/meet/pat"])?.provider == .webex)
    }

    @Test func ignoresOrdinaryLinks() {
        #expect(MeetingLinks.joinLink(in: ["https://zoom.us/pricing", "https://example.com", "Lunch at noon"]) == nil)
        #expect(MeetingLinks.joinLink(in: [nil, ""]) == nil)
    }
}

@MainActor
@Suite("To-dos")
struct TodoStoreTests {
    private func makeStore() -> (TodoStore, UserDefaults) {
        let defaults = UserDefaults(suiteName: "NotchTests-\(UUID().uuidString)")!
        return (TodoStore(defaults: defaults), defaults)
    }

    @Test func addsTicksAndRemembers() throws {
        let (store, defaults) = makeStore()
        store.add("  Buy milk ")
        store.add("Call Sam")
        store.add("   ")
        #expect(store.items.map(\.title) == ["Call Sam", "Buy milk"], "newest first, blanks ignored")
        let milk = try #require(store.items.last)
        store.toggle(milk.id)
        #expect(store.ordered.last?.title == "Buy milk", "done ones sink to the bottom")
        #expect(store.openCount == 1)
        #expect(TodoStore(defaults: defaults).items == store.items, "saved on this Mac")
        store.clearDone()
        #expect(store.items.map(\.title) == ["Call Sam"])
    }

    @Test func keepsAtMostFifty() {
        let (store, _) = makeStore()
        for index in 0..<60 { store.add("Task \(index)") }
        #expect(store.items.count == TodoStore.capacity)
        #expect(store.items.first?.title == "Task 59")
    }
}

@MainActor
@Suite("Formatted notes")
struct RichNotesTests {
    @Test func keepsFormattingAcrossLaunches() throws {
        let defaults = try #require(UserDefaults(suiteName: "NotchTests-\(UUID().uuidString)"))
        let notes = NotesStore(defaults: defaults)
        let bold = NSAttributedString(string: "Ship it", attributes: [.font: NSFontManager.shared.convert(.systemFont(ofSize: 13), toHaveTrait: .boldFontMask)])
        notes.update(bold)
        notes.save()
        let reloaded = NotesStore(defaults: defaults)
        #expect(reloaded.text == "Ship it")
        let font = try #require(reloaded.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
    }

    @Test func plainTextFromAnOlderVersionWins() throws {
        let defaults = try #require(UserDefaults(suiteName: "NotchTests-\(UUID().uuidString)"))
        let notes = NotesStore(defaults: defaults)
        notes.update(NSAttributedString(string: "Old"))
        notes.save()
        defaults.set("Edited elsewhere", forKey: "notes.text")
        #expect(NotesStore(defaults: defaults).attributedText.string == "Edited elsewhere")
    }
}

@Suite("Drop zones")
struct DropZoneTests {
    @Test func theWholeContentIsTheTray() {
        let content = CGRect(x: 100, y: 0, width: 400, height: 100)
        #expect(DropPolicy.destination(at: CGPoint(x: 120, y: 50), content: content, tray: true) == .tray)
        #expect(DropPolicy.destination(at: CGPoint(x: 490, y: 50), content: content, tray: true) == .tray)
        #expect(DropPolicy.destination(at: CGPoint(x: 490, y: 50), content: content, tray: false) == nil)
        #expect(DropPolicy.destination(at: CGPoint(x: 50, y: 50), content: content, tray: true) == nil)
    }
}

@Suite("Grid pages")
struct GridPageTests {
    @Test func fiveToARowTenToAPage() {
        #expect(LauncherBody.columns == 5)
        #expect(LauncherBody.pages(LauncherItem.allCases).count == 1, "every tile fits one page")
        let eleven = LauncherItem.allCases + [.timer, .stopwatch]
        let pages = LauncherBody.pages(Array(eleven.prefix(11)))
        #expect(pages.count == 2)
        #expect(pages[0].count == 10 && pages[1].count == 1)
        #expect(LauncherBody.pages(Array(LauncherItem.allCases.prefix(4))).count == 1)
        #expect(LauncherBody.pages([]).count == 1, "an empty grid still has its page")
    }
}

@Suite("Hardening")
struct HardeningTests {
    @Test func absurdTrackLengthsDontCrashTheClock() {
        #expect(TimeFormatting.clock(1e300) == "999:00:00")
        #expect(TimeFormatting.remaining(elapsed: 0, duration: .greatestFiniteMagnitude) == "-999:00:00")
        #expect(TimeFormatting.clock(-5) == "0:00")
    }

    @MainActor @Test func trayKeepsTheNewestFirst() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = (1...6).map { folder.appendingPathComponent("file\($0).txt") }
        for file in files { try Data("x".utf8).write(to: file) }
        let tray = TrayStore(folder: folder)
        for file in files { tray.add([file]) }
        // The drop view's preview shows the first four: the most recent ones.
        #expect(tray.items.prefix(4).map(\.url.lastPathComponent) == ["file6.txt", "file5.txt", "file4.txt", "file3.txt"])
    }
}
