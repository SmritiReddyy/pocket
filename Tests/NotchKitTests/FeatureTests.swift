import Foundation
import AppKit
import Testing
@testable import NotchKit

private func tempFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NotchTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

@MainActor
@Suite("File Tray")
struct TrayTests {
    @Test func addsRealFilesOnceNewestFirst() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let a = folder.appendingPathComponent("a.txt")
        let b = folder.appendingPathComponent("b.txt")
        try Data("a".utf8).write(to: a)
        try Data("b".utf8).write(to: b)
        let tray = TrayStore(folder: nil)
        #expect(tray.add([a]) == 1)
        #expect(tray.add([b, a, folder.appendingPathComponent("missing.txt")]) == 1)
        #expect(tray.items.map(\.name) == ["b.txt", "a.txt"])
    }

    @Test func startsEmptyInANewSession() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = folder.appendingPathComponent("store", isDirectory: true)
        let keep = folder.appendingPathComponent("keep.pdf")
        let gone = folder.appendingPathComponent("gone.pdf")
        try Data().write(to: keep)
        try Data().write(to: gone)
        TrayStore(folder: store).add([keep, gone])
        try FileManager.default.removeItem(at: gone)
        let reloaded = TrayStore(folder: store)
        #expect(reloaded.items.isEmpty)
        #expect(FileManager.default.fileExists(atPath: keep.path))
    }

    @Test func removeAndClear() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = try (0..<3).map { index -> URL in
            let url = folder.appendingPathComponent("\(index).txt")
            try Data().write(to: url)
            return url
        }
        let tray = TrayStore(folder: nil)
        tray.add(files)
        tray.remove(tray.items[0].id)
        #expect(tray.items.count == 2)
        tray.removeAll()
        #expect(tray.items.isEmpty)
    }

    @Test func pruneDropsMovedFiles() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("x.txt")
        try Data().write(to: file)
        let tray = TrayStore(folder: nil)
        tray.add([file])
        try FileManager.default.removeItem(at: file)
        tray.pruneMissing()
        #expect(tray.items.isEmpty)
    }

    @Test func capacityRejectsOverflowWithoutEviction() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = try (0..<(TrayStore.capacity + 5)).map { index -> URL in
            let url = folder.appendingPathComponent("\(index).txt")
            try Data().write(to: url)
            return url
        }
        let tray = TrayStore(folder: nil)
        for file in files { tray.add([file]) }
        #expect(tray.items.count == TrayStore.capacity)
        #expect(tray.items.first?.name == "\(TrayStore.capacity - 1).txt")
    }
    @Test func webShortcutsAreUniqueAndCleanedWithoutDeletingOriginals() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("original.txt")
        try Data().write(to: file)
        let tray = TrayStore(folder: folder)
        let first = try #require(URL(string: "https://example.com/first"))
        let second = try #require(URL(string: "https://example.com/second"))
        #expect(tray.add([first, second, file]) == 3)
        #expect(tray.add([first]) == 0)
        let shortcuts = tray.items.filter { $0.url.pathExtension == "webloc" }
        #expect(Set(shortcuts.map(\.url)).count == 2)
        let removed = try #require(shortcuts.first)
        tray.remove(removed.id)
        #expect(!FileManager.default.fileExists(atPath: removed.url.path))
        tray.removeAll()
        #expect(shortcuts.allSatisfy { !FileManager.default.fileExists(atPath: $0.url.path) })
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func overflowDoesNotCreateShortcutFilesAndWriteErrorsAreReported() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = try (0..<TrayStore.capacity).map { index -> URL in
            let url = folder.appendingPathComponent("\(index).txt")
            try Data().write(to: url)
            return url
        }
        let tray = TrayStore(folder: folder)
        #expect(tray.add(files) == TrayStore.capacity)
        let before = try FileManager.default.subpathsOfDirectory(atPath: folder.path).count
        let link = try #require(URL(string: "https://example.com/new"))
        #expect(tray.add([link]) == 0)
        let after = try FileManager.default.subpathsOfDirectory(atPath: folder.path).count
        #expect(before == after)
        let invalidBase = try #require(files.first)
        let failingTray = TrayStore(folder: invalidBase)
        #expect(failingTray.add([link]) == 0)
        #expect(failingTray.statusMessage != nil)
    }

    @Test func disabledDestinationsCannotReceiveFiles() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("document.txt")
        try Data().write(to: file)
        let defaults = UserDefaults(suiteName: "DropTests-" + UUID().uuidString)!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: folder))
        model.settings.trayEnabled = false
        #expect(!model.acceptDrop([file], into: .tray))
        #expect(model.tray.items.isEmpty)
    }

    @Test func distinctPagesPackagesAreNotDuplicates() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = [folder.appendingPathComponent("file1.pages"),
                     folder.appendingPathComponent("file2.pages"),
                     folder.appendingPathComponent("other/file1.pages")]
        for file in files {
            try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        }
        let tray = TrayStore(folder: folder)
        #expect(tray.add(files) == 3)
        #expect(Set(tray.items.map(\.url)) == Set(files.map(\.standardizedFileURL)))
        #expect(tray.add([files[0]]) == 0)
        #expect(tray.items.count == 3)
    }

    @Test func nativePasteboardReadsIndividualFilesAndLinks() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let first = URL(fileURLWithPath: "/tmp/first.pages")
        let second = URL(fileURLWithPath: "/tmp/second.pages")
        let a = NSPasteboardItem()
        let b = NSPasteboardItem()
        a.setString(first.absoluteString, forType: .fileURL)
        b.setString(second.absoluteString, forType: .fileURL)
        #expect(pasteboard.writeObjects([a, b]))
        #expect(FileDropReader.urls(from: pasteboard) == [first, second])
        pasteboard.clearContents()
        let web = NSPasteboardItem()
        let link = try #require(URL(string: "https://example.com/document"))
        web.setString(link.absoluteString, forType: .URL)
        #expect(pasteboard.writeObjects([web]))
        #expect(FileDropReader.urls(from: pasteboard) == [link])
    }

    @Test func documentReleaseAcceptsNotchEdgeAndExpandedTarget() {
        let activation = CGRect(x: 100, y: 0, width: 200, height: 100)
        let pill = CGRect(x: 80, y: 20, width: 240, height: 150)
        let target = DocumentDragPolicy.dropRegion(activation: activation, pill: pill)
        #expect(target.contains(CGPoint(x: 200, y: 0)))
        #expect(target.contains(CGPoint(x: 100, y: 150)))
        #expect(!target.contains(CGPoint(x: 400, y: 200)))
    }

    @Test func windowMovementAndDestinationPolicy() {
        #expect(!DocumentDragPolicy.hasMoved(from: .zero, to: CGPoint(x: 2, y: 0)))
        #expect(DocumentDragPolicy.hasMoved(from: .zero, to: CGPoint(x: 10, y: 0)))
        let content = CGRect(x: 0, y: 0, width: 200, height: 100)
        #expect(DropPolicy.destination(at: CGPoint(x: 20, y: 20), content: content, tray: false) == nil)
        #expect(DropPolicy.destination(at: CGPoint(x: 150, y: 20), content: content, tray: true) == .tray)
    }

}

@Suite("Calendar rules")
struct CalendarRuleTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    private func event(_ id: String, startsIn minutes: Double, lasts: Double = 30) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarEvent(id: id, title: id, start: start, end: start.addingTimeInterval(lasts * 60))
    }

    @Test func nextEventPrefersWhatIsHappeningNow() {
        let events = [event("later", startsIn: 60), event("now", startsIn: -10), event("over", startsIn: -90)]
        #expect(CalendarRules.nextEvent(in: events, at: now)?.id == "now")
        #expect(CalendarRules.nextEvent(in: [event("over", startsIn: -90)], at: now) == nil)
    }

    @Test func reminderFiveMinutesBeforeAndOnlyOnce() throws {
        let events = [event("a", startsIn: 20), event("b", startsIn: 3)]
        let first = try #require(CalendarRules.nextReminder(in: events, after: now, reminded: []))
        #expect(first.event.id == "b")
        #expect(first.at == now, "already inside the 5-minute window: remind right away")
        let second = try #require(CalendarRules.nextReminder(in: events, after: now, reminded: ["b"]))
        #expect(second.event.id == "a")
        #expect(second.at == now.addingTimeInterval(15 * 60))
        #expect(CalendarRules.nextReminder(in: events, after: now, reminded: ["a", "b"]) == nil)
        #expect(CalendarRules.nextReminder(in: [event("started", startsIn: -1)], after: now, reminded: []) == nil)
    }

    @Test func labels() {
        #expect(CalendarRules.relativeLabel(for: event("x", startsIn: -5), at: now) == "now")
        #expect(CalendarRules.relativeLabel(for: event("x", startsIn: 12), at: now) == "in 12 min")
        #expect(CalendarRules.relativeLabel(for: event("x", startsIn: 0.2), at: now) == "in 1 min")
        #expect(CalendarRules.relativeLabel(for: event("x", startsIn: 75), at: now) == "in 1 hr")
    }
}

@Suite("Home and alerts for new features")
struct NewFeatureLayoutTests {
    let engine = LayoutEngine(screen: .sample, appearance: .standard)

    @Test func nookIsWideShortAndTheSameForEveryTab() throws {
        let notch = try #require(ScreenMetrics.sample.notch)
        let full = HomeContent(hasEvent: true, hasTimer: true)
        #expect(full.fitsInNook, "three widget rows fit in the column")
        let sizes = [IslandPresentation.home, .tray, .mirror].map { engine.layout(for: $0, home: full, hovering: false).pill.size }
        #expect(Set(sizes.map { "\($0)" }).count == 1, "switching tabs never resizes the shape")
        let home = engine.layout(for: .home, home: full, hovering: false)
        #expect(home.pill.width > home.pill.height * 2.5, "wide, not tall")
        #expect(home.pill.height <= notch.height + IslandMetrics.Nook.body + 30)
        #expect(home.stripHeight == notch.height, "tabs sit beside the camera")
        #expect(home.cameraGap == notch.width)
        #expect(home.content.minY == 0)
        let empty = engine.layout(for: .home, home: HomeContent(hasTimer: false), hovering: false)
        #expect(empty.pill == home.pill)
    }

    @Test func nookBodySitsEvenlyBetweenTheStripAndTheBottom() throws {
        let notch = try #require(ScreenMetrics.sample.notch)
        let home = engine.layout(for: .home, home: HomeContent(), hovering: false)
        let above = IslandMetrics.notchContentGap + IslandMetrics.Nook.bodyTopInset
        let below = home.pill.height - home.content.height
        #expect(home.content.height == notch.height + above + IslandMetrics.Nook.body)
        #expect(abs(above - below) <= 2, "the body doesn't hug the strip")
    }

    @Test func everyTabFitsTheWindow() {
        let full = HomeContent(hasEvent: true, hasTimer: true)
        let external = ScreenMetrics(size: CGSize(width: 1920, height: 1080), notch: nil, menuBarHeight: 25)
        for screen in [ScreenMetrics.sample, external] {
            let engine = LayoutEngine(screen: screen, appearance: .standard)
            let bounds = CGRect(origin: .zero, size: engine.windowSize)
            for presentation in [IslandPresentation.home, .tray, .mirror, .nook(.launcher)] {
                let layout = engine.layout(for: presentation, home: full, hovering: false)
                #expect(bounds.contains(layout.pill), "\(presentation)")
            }
        }
    }

    @Test func tabsResolve() {
        #expect(PresentationResolver.resolve(PresentationInput(expandTarget: .tray)) == .tray)
        #expect(PresentationResolver.resolve(PresentationInput(expandTarget: .mirror)) == .mirror)
        #expect(IslandPresentation.tray.isExpandedFamily && IslandPresentation.mirror.isExpandedFamily)
        #expect(IslandPresentation.tray.homeTab == .tray)
        #expect(ExpandTarget(.mirror) == .mirror)
    }

}

@MainActor
@Suite("Model: tray, tabs and drops")
struct NewFeatureModelTests {
    private func makeModel() -> IslandModel {
        let defaults = UserDefaults(suiteName: "NewFeatureModelTests.\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil))
        model.screen = .sample
        return model
    }

    @Test func droppingIntoTheTrayShowsIt() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("doc.txt")
        try Data().write(to: file)
        let model = makeModel()
        let zone = model.engine.dropZone
        model.fileDragChanged(isDragging: true, at: CGPoint(x: zone.midX, y: 5))
        model.setTargeted(.tray, true)
        #expect(model.targetedZone == .tray)
        #expect(model.presentation == .drop(targeted: true))
        model.addToTray([file])
        #expect(model.presentation == .tray)
        #expect(model.tray.items.count == 1)
    }

    @Test func draggingOutOfTheTrayIsNotANewDrop() {
        let model = makeModel()
        model.showTab(.tray)
        model.isDraggingFromTray = true
        model.fileDragChanged(isDragging: true, at: CGPoint(x: model.engine.dropZone.midX, y: 5))
        #expect(model.presentation == .tray)
        model.fileDragChanged(isDragging: false, at: nil)
        #expect(!model.isDraggingFromTray)
    }

    @Test func dropsNeedADestination() {
        let model = makeModel()
        model.settings.trayEnabled = false
        model.fileDragChanged(isDragging: true, at: CGPoint(x: model.engine.dropZone.midX, y: 5))
        #expect(model.presentation == .hidden(peek: false))
    }

    @Test func tabsFollowSettings() {
        let model = makeModel()
        #expect(model.homeTabs == [.home, .tray, .clipboard])
        model.settings.mirrorEnabled = false
        model.settings.clipboardEnabled = false
        model.settings.notesEnabled = false
        #expect(model.homeTabs == [.home, .tray])
    }

    @Test func homeRowsFollowSettings() {
        let model = makeModel()
        model.settings.calendarEnabled = false
        #expect(!model.homeContent.hasEvent)
        model.settings.timerEnabled = false
        #expect(!model.homeContent.hasTimer)
    }

}

@Suite("Home cards")
struct HomeCardTests {
    @Test func homeWidensForItsCards() {
        let engine = LayoutEngine(screen: .sample, appearance: .standard)
        let plain = engine.layout(for: .home, home: HomeContent(), hovering: false)
        let full = engine.layout(for: .home, home: .full, hovering: false)
        #expect(plain.pill.width == engine.nookWidth + 2 * IslandMetrics.expandedFlare)
        let cards = HomeCard.allCases.reduce(0) { $0 + $1.width + IslandMetrics.Nook.homeCardGap }
        #expect(full.content.width == 2 * IslandMetrics.Nook.sidePadding + IslandMetrics.Nook.homeColumnWidth + cards)
        #expect(full.pill.maxX <= engine.windowSize.width && full.pill.minX >= 0)
        // Only Home grows; the other tabs keep the standard nook.
        #expect(engine.layout(for: .tray, home: .full, hovering: false).pill == plain.pill)
    }

    @Test func everySizeFitsTheScreen() {
        let external = ScreenMetrics(size: CGSize(width: 1280, height: 800), notch: nil, menuBarHeight: 25)
        for screen in [ScreenMetrics.sample, external] {
            for size in [NotchSize.small, .medium, .large] {
                var appearance = NotchAppearance.standard
                appearance.size = size
                let layout = LayoutEngine(screen: screen, appearance: appearance).layout(for: .home, home: .full, hovering: false)
                #expect(layout.pill.minX >= 0 && layout.pill.maxX <= screen.size.width, "\(size) on \(screen.size)")
            }
        }
    }

    @MainActor
    @Test func cardsFollowTheirSettings() {
        let defaults = UserDefaults(suiteName: "HomeCardTests.\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil))
        #expect(model.homeContent.cards == [.notes, .reminders, .clipboard])
        model.settings.remindersEnabled = false
        model.settings.clipboardEnabled = false
        #expect(model.homeContent.cards == [.notes])
        model.settings.notesEnabled = false
        #expect(model.homeContent.cards.isEmpty)
    }
}

@Suite("Peeking face")
struct PeekingFaceTests {
    @Test func peekGrowsForTheFaceOnlyWhenItsOn() throws {
        let notch = try #require(ScreenMetrics.sample.notch)
        var appearance = NotchAppearance.standard
        let withFace = LayoutEngine(screen: .sample, appearance: appearance)
        appearance.peekingFace = false
        let plain = LayoutEngine(screen: .sample, appearance: appearance)
        #expect(plain.layout(for: .hidden(peek: true), home: HomeContent(), hovering: false).pill.height == notch.height + 3)
        #expect(withFace.layout(for: .hidden(peek: true), home: HomeContent(), hovering: false).pill.height
            == notch.height + 3 + IslandMetrics.peekFaceHeight)
        #expect(plain.peekFaceHeight == 0)
    }

    @Test func movingOntoTheFaceKeepsItPeeking() throws {
        let engine = LayoutEngine(screen: .sample, appearance: .standard)
        let notch = try #require(ScreenMetrics.sample.notch)
        let onFace = CGPoint(x: engine.notchInWindow.midX, y: notch.height + 3 + IslandMetrics.peekFaceHeight / 2)
        #expect(!engine.notchHoverRect.contains(onFace), "the face's spot alone doesn't start a peek")
        #expect(engine.peekHoverRect.contains(onFace))
        let peek = engine.layout(for: .hidden(peek: true), home: HomeContent(), hovering: false)
        #expect(engine.interactiveRects(for: .hidden(peek: true), layout: peek).contains { $0.contains(onFace) })
    }

    @MainActor
    @Test func settingPersists() {
        let defaults = UserDefaults(suiteName: "PeekingFaceTests.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        #expect(store.appearance.peekingFace)
        store.appearance.peekingFace = false
        #expect(!SettingsStore(defaults: defaults).appearance.peekingFace)
    }
}

@Suite("Save to Notes")
struct AppleNotesExportTests {
    private let base = NSFont.systemFont(ofSize: 13)

    @Test func linesBecomeDivsAndTextIsEscaped() {
        let note = NSAttributedString(string: "Call Sam <3\n\nBuy milk & eggs", attributes: [.font: base, .foregroundColor: NSColor.white])
        #expect(AppleNotesExporter.html(from: note)
            == "<div>Call Sam &lt;3</div><div><br></div><div>Buy milk &amp; eggs</div>")
    }

    @Test func formattingIsKept() {
        let note = NSMutableAttributedString(string: "Plain ", attributes: [.font: base])
        let bold = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        note.append(NSAttributedString(string: "bold", attributes: [.font: bold]))
        note.append(NSAttributedString(string: " big", attributes: [.font: NSFont.systemFont(ofSize: 18)]))
        note.append(NSAttributedString(string: " under", attributes: [.font: base, .underlineStyle: NSUnderlineStyle.single.rawValue]))
        note.append(NSAttributedString(string: " blue", attributes: [.font: base, .foregroundColor: NSColor(red: 10 / 255, green: 132 / 255, blue: 1, alpha: 1)]))
        let html = AppleNotesExporter.html(from: note)
        #expect(html.hasPrefix("<div>Plain "))
        #expect(html.contains("<b>bold</b>"))
        #expect(html.contains("font-size: 18px\"> big</span>"))
        #expect(html.contains("<u> under</u>"))
        #expect(html.contains("color: #0A84FF\"> blue</span>"))
        #expect(!html.contains("#FFFFFF"), "the notch's white text isn't carried into Notes")
    }

    @Test func permissionErrorsAreRecognised() {
        #expect(AppleNotesExporter.classify("execution error: Not authorised to send Apple events to Notes. (-1743)") == .notAllowed)
        #expect(AppleNotesExporter.classify("execution error: Notes got an error: Can’t make folder. (-10000)") == .other("execution error: Notes got an error: Can’t make folder. (-10000)"))
        #expect(AppleNotesExporter.classify("  ") == .other("Notes didn't respond."))
    }

    @MainActor
    @Test func emptyNotesAreNotSaved() {
        let exporter = AppleNotesExporter()
        exporter.save(NSAttributedString(string: "  \n "))
        #expect(exporter.state == .idle)
    }
}
