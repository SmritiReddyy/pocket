import CoreGraphics

/// Every size used by the shape. DESIGN.md documents these numbers; keep the two in sync.
public enum IslandMetrics {
    /// Width of each leading/trailing slot beside the camera, before the width setting.
    public static func slotWidth(height: CGFloat) -> CGFloat {
        (height * 1.15).rounded()
    }

    /// Width of each region beside the camera ("ear"). The width setting widens it.
    public static func earWidth(_ appearance: NotchAppearance, height: CGFloat) -> CGFloat {
        let slot = slotWidth(height: height)
        return max((slot * 0.8).rounded(), (slot + (appearance.width - 180) / 2).rounded())
    }

    public static func expandedWidth(_ appearance: NotchAppearance) -> CGFloat {
        min(max(appearance.width + 190, 360), 560)
    }

    /// Height of the content area of each expanded view. The shape adds the notch strip above it
    /// and padding below.
    public enum ContentHeight {
        public static let timer: CGFloat = 76
        public static let drop: CGFloat = 100
        public static let timerFinished: CGFloat = 72
        /// Tallest expanded content; sizes the window.
        public static let maximum: CGFloat = Nook.launcherBody + Nook.bodyTopInset
    }

    /// The Home, Tray and Mirror tabs share one fixed-size "nook", like the paid notch apps:
    /// wide and short, with widgets side by side rather than stacked.
    public enum Nook {
        public static let width: CGFloat = 560
        /// Area below the tab header, which sits in the strip beside the camera.
        public static let body: CGFloat = 120
        /// Extra room between the strip and the body, so the body sits as far below
        /// the strip as it does above the bottom edge.
        public static let bodyTopInset: CGFloat = 10
        public static let row: CGFloat = 30
        public static let rowGap: CGFloat = 8
        /// Home: the calendar and timer column when cards sit beside it. Just wide
        /// enough for the timer row with two presets and the Focus button.
        public static let homeColumnWidth: CGFloat = 250
        public static let homeCardGap: CGFloat = 12
        /// Left and right padding inside the nook.
        public static let sidePadding: CGFloat = 20
        /// The grid of features gets more height than the other views, so its tiles can breathe.
        public static let launcherBody: CGFloat = 170
        public static let launcherTile: CGFloat = 76
        public static let launcherGap: CGFloat = 10
        /// Elongated layout: Home, Tray, Clipboard and the grid stretch across the top of the
        /// screen, this wide at most, and never closer than `elongatedEdge` to either side.
        public static let elongatedMaxWidth: CGFloat = 1240
        public static let elongatedEdge: CGFloat = 40
    }

    /// Space between the notch strip and the content, and below the content.
    public static let notchContentGap: CGFloat = 2
    public static let notchBottomPadding: CGFloat = 14
    public static let notchExpandedRadius: CGFloat = 30
    /// Concave shoulders where the shape meets the top edge, like the real notch.
    public static let compactFlare: CGFloat = 6
    public static let expandedFlare: CGFloat = 10
    /// Minimum width of each alert ear, so short alerts fit beside the camera.
    public static let alertEarWidth: CGFloat = 128
    /// Ear width for alerts that show a name (calendar events).
    public static let namedAlertEarWidth: CGFloat = 156

    /// Room around the content for the shadow.
    public static let windowMargin: CGFloat = 48
    /// Closest the widest view may come to a screen edge.
    public static let screenEdgeInset: CGFloat = 8
    /// How much a hovered compact shape grows (horizontal each side, vertical).
    public static let hoverGrowth = CGSize(width: 3, height: 2)
    /// Extra hit area around the shape so the pointer doesn't have to be pixel-perfect.
    public static let hitSlop: CGFloat = 4
    /// Displays without a notch get a virtual one at the top centre, the size of a MacBook's.
    /// It's only drawn while something is showing, or once the pointer rests on its spot.
    public static let virtualNotchWidth: CGFloat = 180
    /// Room below the notch for the face that peeks out while it's hovered.
    public static let peekFaceHeight: CGFloat = 22
    /// Never shorter than this, so the tabs and content beside it fit as they do on a MacBook.
    public static let virtualNotchMinHeight: CGFloat = 32
}

/// A card beside the widget column on Home.
public enum HomeCard: String, CaseIterable, Sendable, Hashable {
    case notes
    case reminders
    case clipboard

    /// Width before Small / Medium / Large scaling.
    public var width: CGFloat {
        switch self {
        case .notes: 160
        case .reminders: 180
        case .clipboard: 150
        }
    }
}

/// Which widgets the Home tab shows.
public struct HomeContent: Equatable, Sendable {
    public var hasEvent: Bool
    public var hasTimer: Bool
    /// Cards beside the column, in order.
    public var cards: [HomeCard]

    public init(hasEvent: Bool = false, hasTimer: Bool = true, cards: [HomeCard] = []) {
        self.hasEvent = hasEvent
        self.hasTimer = hasTimer
        self.cards = cards
    }

    /// Every widget and card switched on.
    public static let full = HomeContent(hasEvent: true, hasTimer: true, cards: HomeCard.allCases)

    /// Home's width before scaling: the standard nook, widened to fit the cards beside the column.
    public var width: CGFloat {
        typealias Nook = IslandMetrics.Nook
        guard !cards.isEmpty else { return Nook.width }
        let cardsWidth = cards.reduce(0) { $0 + $1.width + Nook.homeCardGap }
        return max(Nook.width, 2 * Nook.sidePadding + Nook.homeColumnWidth + cardsWidth)
    }

    /// Rows in the widget column (calendar, timer).
    public var rowCount: Int {
        [hasEvent, hasTimer].filter { $0 }.count
    }

    /// Every row fits in the nook without scrolling.
    public var fitsInNook: Bool {
        typealias Nook = IslandMetrics.Nook
        let rows = CGFloat(rowCount)
        return rows * Nook.row + max(0, rows - 1) * Nook.rowGap <= Nook.body
    }
}
