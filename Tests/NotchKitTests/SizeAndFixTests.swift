import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import NotchKit

@Suite("Size modes")
struct SizeModeTests {
    let screen = ScreenMetrics.sample

    private func engine(_ size: NotchSize, screen: ScreenMetrics = .sample) -> LayoutEngine {
        var appearance = NotchAppearance.standard
        appearance.size = size
        return LayoutEngine(screen: screen, appearance: appearance)
    }

    @Test func largeIsTheOriginalDesign() {
        #expect(NotchAppearance.standard.size == .large)
        let large = engine(.large)
        #expect(large.scale == 1)
        #expect(large.compactBodyWidth == CGFloat(180 + 2 * 47))
        #expect(large.expandedWidth == CGFloat(390))
        #expect(large.expandedContentHeight(for: .expanded(.call), home: HomeContent()) == IslandMetrics.ContentHeight.call)
    }

    @Test func smallerSizesShrinkEverything() {
        let presentations: [IslandPresentation] = [
            .compact(primary: .timer, secondary: .stopwatch), .expanded(.call), .expanded(.timer), .home,
            .alert(.charging(level: 50, isCharging: true)), .alert(.timerFinished), .drop(targeted: false),
        ]
        let external = ScreenMetrics(size: CGSize(width: 1920, height: 1080), notch: nil, menuBarHeight: 25)
        for screen in [ScreenMetrics.sample, external] {
            for presentation in presentations {
                let sizes = [NotchSize.small, .medium, .large].map {
                    engine($0, screen: screen).layout(for: presentation, home: HomeContent(), hovering: false)
                }
                #expect(sizes[0].pill.width <= sizes[1].pill.width && sizes[1].pill.width <= sizes[2].pill.width, "\(presentation)")
                #expect(sizes[0].pill.height <= sizes[1].pill.height && sizes[1].pill.height <= sizes[2].pill.height, "\(presentation)")
                #expect(sizes.map(\.contentScale) == [0.8, 0.9, 1])
            }
        }
    }

    @Test func notchCompactStaysAtLeastNotchHeightAndClearsTheCamera() throws {
        let notch = try #require(screen.notch)
        let small = engine(.small).layout(for: .compact(primary: .timer, secondary: nil), home: HomeContent(), hovering: false)
        #expect(small.pill.height == notch.height)
        #expect(small.cameraGap == notch.width)
        #expect(small.content.width - notch.width >= 2 * 30, "ears still hold an icon and a countdown")
    }

    @Test func smallExpandedStillFitsItsContent() {
        let small = engine(.small)
        #expect(small.expandedWidth >= small.compactBodyWidth + 40)
        let height = small.expandedContentHeight(for: .expanded(.call), home: HomeContent())
        #expect(height == (IslandMetrics.ContentHeight.call * 0.8).rounded())
    }

    @MainActor
    @Test func sizePersists() {
        let name = "SizeModeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: defaults)
        store.appearance.size = .small
        #expect(SettingsStore(defaults: defaults).appearance.size == .small)
        defaults.set("gigantic", forKey: "shape.size")
        #expect(SettingsStore(defaults: defaults).appearance.size == .large, "unknown values fall back to Large")
    }
}

@Suite("Window")
struct WindowTests {
    @Test func windowIsFixedForADisplay() {
        let screen = ScreenMetrics.sample
        var sizes = Set<CGSize.Hashable>()
        for size in NotchSize.allCases {
            for width in [120.0, 200, 420] {
                for height in [24.0, 32, 52] {
                    var appearance = NotchAppearance.standard
                    appearance.size = size
                    appearance.width = width
                    appearance.height = height
                    let engine = LayoutEngine(screen: screen, appearance: appearance)
                    sizes.insert(CGSize.Hashable(engine.windowSize))
                    #expect(engine.windowOriginX == 0)
                }
            }
        }
        #expect(sizes.count == 1, "settings never move or resize the window")
        #expect(sizes.first?.width == screen.size.width)
    }
}

private extension CGSize {
    struct Hashable: Swift.Hashable {
        let width: CGFloat
        let height: CGFloat
        init(_ size: CGSize) {
            width = size.width
            height = size.height
        }
    }
}

@MainActor
@Suite("Model fixes")
struct ModelFixTests {
    private func makeModel() -> IslandModel {
        let name = "ModelFixTests.\(UUID().uuidString)"
        let model = IslandModel(settings: SettingsStore(defaults: UserDefaults(suiteName: name)!), tray: TrayStore(folder: nil))
        model.screen = .sample
        return model
    }

    @Test func timerDoneInterruptsAnotherAlert() {
        let model = makeModel()
        model.receive(.charging(level: 40, isCharging: true))
        #expect(model.presentation == .alert(.charging(level: 40, isCharging: true)))
        model.receive(.timerFinished)
        #expect(model.presentation == .alert(.timerFinished))
        model.stopTimerAlarm()
        #expect(model.presentation == .alert(.charging(level: 40, isCharging: true)), "the interrupted alert comes back")
    }

    @Test func welcomeIsShownOnce() {
        let name = "ModelFixTests.welcome.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: defaults)
        #expect(!store.hasShownWelcome)
        store.hasShownWelcome = true
        #expect(SettingsStore(defaults: defaults).hasShownWelcome)
    }

    @Test func clickingAnAlertDismissesItButNotTimerDone() {
        let model = makeModel()
        model.receive(.welcome)
        model.tapPill()
        #expect(model.presentation == .hidden(peek: false))
        model.receive(.timerFinished)
        model.tapPill()
        #expect(model.presentation == .alert(.timerFinished), "needs Stop or Repeat")
    }

    @Test func sizeChangesTheLiveLayout() {
        let model = makeModel()
        model.startTimer(60)
        let large = model.layout.pill.width
        model.settings.appearance.size = .small
        #expect(model.layout.pill.width < large)
        #expect(model.layout.contentScale == 0.8)
    }
}
