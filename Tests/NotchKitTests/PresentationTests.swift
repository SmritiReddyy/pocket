import Testing
@testable import NotchKit

@Suite("Presentation rules")
struct PresentationTests {
    @Test func hiddenWhenNothingIsHappening() {
        #expect(PresentationResolver.resolve(PresentationInput()) == .hidden(peek: false))
    }

    @Test func notchHoverPeeksOnlyWhenHidden() {
        #expect(PresentationResolver.resolve(PresentationInput(isHoveringNotch: true)) == .hidden(peek: true))
        let busy = PresentationInput(activeActivities: [.timer], isHoveringNotch: true)
        #expect(PresentationResolver.resolve(busy) == .compact(primary: .timer, secondary: nil))
    }

    @Test func idleWhenAskedOrPreviewing() {
        #expect(PresentationResolver.resolve(PresentationInput(showWhenIdle: true)) == .idle)
        #expect(PresentationResolver.resolve(PresentationInput(isPreviewing: true)) == .idle)
    }

    @Test func priorityIsTimerThenStopwatch() {
        let two = PresentationInput(activeActivities: [.stopwatch, .timer])
        #expect(PresentationResolver.resolve(two) == .compact(primary: .timer, secondary: .stopwatch))
    }

    @Test func swipeChoiceWinsWhileActive() {
        let input = PresentationInput(activeActivities: [.stopwatch, .timer], preferredPrimary: .stopwatch)
        #expect(PresentationResolver.resolve(input) == .compact(primary: .stopwatch, secondary: .timer))
        let stale = PresentationInput(activeActivities: [.timer], preferredPrimary: .stopwatch)
        #expect(PresentationResolver.resolve(stale) == .compact(primary: .timer, secondary: nil))
    }

    @Test func swipingVisitsEveryActivity() {
        let all: Set<ActivityKind> = [.timer, .stopwatch]
        var current: ActivityKind? = .timer
        var seen: [ActivityKind] = []
        for _ in 0..<2 {
            current = PresentationResolver.nextPrimary(all, current: current, forward: true)
            seen.append(current!)
        }
        #expect(seen == [.stopwatch, .timer])
        #expect(PresentationResolver.nextPrimary(all, current: .timer, forward: false) == .stopwatch)
        #expect(PresentationResolver.nextPrimary([.timer], current: .timer, forward: true) == nil)
        #expect(PresentationResolver.nextPrimary([.timer, .stopwatch], current: nil, forward: true) == .stopwatch)
    }

    @Test func expandedOnlyForActiveActivities() {
        let valid = PresentationInput(activeActivities: [.timer], expandTarget: .activity(.timer))
        #expect(PresentationResolver.resolve(valid) == .expanded(.timer))
        let ended = PresentationInput(activeActivities: [], expandTarget: .activity(.timer))
        #expect(PresentationResolver.resolve(ended) == .hidden(peek: false))
        #expect(PresentationResolver.resolve(PresentationInput(expandTarget: .home)) == .home)
    }

    @Test func alertsBeatExpandedAndDragBeatsAlerts() {
        let alert = PresentationInput(activeActivities: [.timer], alert: .upcomingEvent(title: "Event 10", minutes: 5), expandTarget: .home)
        #expect(PresentationResolver.resolve(alert) == .alert(.upcomingEvent(title: "Event 10", minutes: 5)))
        var drag = alert
        drag.isFileDragNear = true
        #expect(PresentationResolver.resolve(drag) == .drop(targeted: false))
        drag.isDropTargeted = true
        #expect(PresentationResolver.resolve(drag) == .drop(targeted: true))
    }

    @Test func topologyChangesOnlyOnShapeChanges() {
        let compact = IslandPresentation.compact(primary: .timer, secondary: nil)
        let other = IslandPresentation.compact(primary: .stopwatch, secondary: nil)
        #expect(compact.topology == other.topology)
        #expect(compact.topology != IslandPresentation.compact(primary: .timer, secondary: .stopwatch).topology)
        #expect(compact.topology != IslandPresentation.hidden(peek: false).topology)
        #expect(IslandPresentation.home.topology == IslandPresentation.expanded(.timer).topology)
    }

    @Test func families() {
        #expect(IslandPresentation.home.isExpandedFamily)
        #expect(IslandPresentation.drop(targeted: false).isExpandedFamily)
        #expect(!IslandPresentation.idle.isExpandedFamily)
        #expect(IslandPresentation.idle.isRestingPill)
        #expect(IslandPresentation.compact(primary: .stopwatch, secondary: nil).isRestingPill)
        #expect(!IslandPresentation.hidden(peek: true).isVisible)
    }
}
