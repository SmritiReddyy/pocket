import SwiftUI

/// A little face that peeks out from under the notch while it's hovered: two eyes that blink and
/// glance around, and a small smile.
struct PeekFace: View {
    /// Designed at 22pt tall; this sets the actual height.
    let height: CGFloat
    @State private var isBlinking = false
    @State private var glance: CGFloat = 0
    @State private var isHello = true

    var body: some View {
        let unit = height / 22
        VStack(spacing: 2.5 * unit) {
            HStack(spacing: 10 * unit) {
                eye(unit)
                eye(unit)
            }
            .offset(x: glance * unit)
            Smile()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8 * unit, lineCap: .round))
                .frame(width: 9.5 * unit, height: 3.5 * unit)
                .scaleEffect(isHello ? 1.25 : 1)
        }
        .frame(height: height)
        .accessibilityHidden(true)
        .task { await live() }
    }

    private func eye(_ unit: CGFloat) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: 5.5 * unit, height: 8 * unit)
            .scaleEffect(x: 1, y: isBlinking ? 0.12 : 1, anchor: .center)
    }

    /// Says hello with a big smile, then blinks every few seconds and now and then looks aside.
    private func live() async {
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) { isHello = false }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1600...3400)))
            guard !Task.isCancelled else { return }
            if Bool.random() {
                withAnimation(.easeInOut(duration: 0.25)) { glance = [-1.6, 1.6, 0].randomElement() ?? 0 }
            }
            withAnimation(.easeIn(duration: 0.07)) { isBlinking = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeOut(duration: 0.1)) { isBlinking = false }
        }
    }
}

/// The lower half of a circle, drawn as an open curve.
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY))
        return path
    }
}
