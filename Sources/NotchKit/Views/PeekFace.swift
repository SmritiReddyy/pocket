import SwiftUI

/// A little face that peeks out from under the notch while it's hovered: two eyes that blink,
/// wink and glance around, and a small smile.
struct PeekFace: View {
    /// Designed at 22pt tall; this sets the actual height.
    let height: CGFloat
    @State private var isBlinking = false
    @State private var glance: CGFloat = 0
    @State private var isHello = true
    /// 0 is the left eye, 1 the right.
    @State private var winkingEye: Int?

    var body: some View {
        let unit = height / 22
        VStack(spacing: 2.5 * unit) {
            HStack(spacing: 10 * unit) {
                eye(0, unit)
                eye(1, unit)
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

    /// An open eye, or a happy closed curve while it winks.
    private func eye(_ index: Int, _ unit: CGFloat) -> some View {
        let winking = winkingEye == index
        return ZStack {
            Capsule()
                .fill(Color.white)
                .scaleEffect(x: 1, y: isBlinking || winking ? 0.12 : 1, anchor: .center)
                .opacity(winking ? 0 : 1)
            Lid()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8 * unit, lineCap: .round))
                .frame(height: 3 * unit)
                .scaleEffect(winking ? 1 : 0.4)
                .opacity(winking ? 1 : 0)
        }
        .frame(width: 5.5 * unit, height: 8 * unit)
    }

    /// Says hello with a big smile and a wink, then blinks every few seconds, winks now and
    /// then, and sometimes looks aside.
    private func live() async {
        try? await Task.sleep(for: .milliseconds(300))
        await wink(eye: 1, for: 550)
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) { isHello = false }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1600...3400)))
            guard !Task.isCancelled else { return }
            if Bool.random() {
                withAnimation(.easeInOut(duration: 0.25)) { glance = [-1.6, 1.6, 0].randomElement() ?? 0 }
            }
            if Int.random(in: 0..<4) == 0 {
                await wink(eye: Int.random(in: 0...1), for: 400)
            } else {
                withAnimation(.easeIn(duration: 0.07)) { isBlinking = true }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.1)) { isBlinking = false }
            }
        }
    }

    private func wink(eye: Int, for milliseconds: Int) async {
        withAnimation(.spring(duration: 0.2, bounce: 0.3)) { winkingEye = eye }
        try? await Task.sleep(for: .milliseconds(milliseconds))
        withAnimation(.easeOut(duration: 0.15)) { winkingEye = nil }
    }
}

/// A closed, smiling eye: an upward curve like the top of a ^.
private struct Lid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY * 2 - rect.maxY))
        return path
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
