import Foundation

/// Numbers for the liquid effect.
public enum GooMath {
    /// Blur radius at full strength. Small enough that a 24 pt pill never blurs away.
    public static let maximumBlur: Double = 7

    public static func blurRadius(strength: Double) -> Double {
        maximumBlur * min(max(strength, 0), 1)
    }

    /// Alpha multiplier that turns the blurred edge back into a sharp one about 1.5 px wide.
    /// At zero blur it is 1, so the effect fades out without a visible jump.
    public static func alphaSlope(blurRadius: Double, displayScale: Double) -> Double {
        max(1, 1.67 * blurRadius * max(displayScale, 1))
    }

    /// Bias that keeps the visible edge at half coverage for any slope.
    public static func alphaBias(slope: Double) -> Double {
        0.5 - 0.5 * slope
    }
}
