import SwiftUI

/// Spacing scale: window margin, gap between tiles, padding inside a tile.
enum Space {
    static let margin: CGFloat = 16
    static let gap: CGFloat = 12
    static let inset: CGFloat = 14
    static let radius: CGFloat = 12
}

struct KeyCap: View {
    let label: String

    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 20)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.14)))
    }
}

enum ParakeetPalette {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.08)
    static let surface = Color(red: 0.085, green: 0.095, blue: 0.115)
    static let yellow = Color(red: 246.0 / 255.0, green: 216.0 / 255.0, blue: 24.0 / 255.0)
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryLabel(configuration: configuration)
    }

    private struct PrimaryLabel: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.black : Color.secondary)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(fill, in: RoundedRectangle(cornerRadius: 8))
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: hovering)
                .onHover { hovering = $0 }
        }

        private var fill: Color {
            guard isEnabled else { return Color.white.opacity(0.08) }
            if configuration.isPressed { return ParakeetPalette.yellow.opacity(0.8) }
            return hovering ? ParakeetPalette.yellow.opacity(0.92) : ParakeetPalette.yellow
        }
    }
}

/// Transcribing animation: a live, layered-sine spectrum on the right that a scan head
/// "reads" into settled, text-like lines on the left as `progress` (0...1) rises.
struct ProcessingWaveform: View {
    var progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false

    private static let columns = 44
    private static let rows: [CGFloat] = [-14, 0, 14]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30,
                                paused: reduceMotion || scenePhase != .active || !visible)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size,
                     time: reduceMotion ? 0.8 : timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: 300, height: 64)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let accent = ParakeetPalette.yellow
        let midY = size.height / 2
        let pitch = size.width / CGFloat(Self.columns)
        let barWidth = max(2, pitch * 0.46)
        let clamped = min(max(progress, 0), 1)
        let head = 8 + (size.width - 16) * CGFloat(clamped)
        let blend: CGFloat = 26

        // Faint baseline.
        context.fill(Path(CGRect(x: 0, y: midY - 0.5, width: size.width, height: 1)),
                     with: .color(accent.opacity(0.08)))

        for index in 0..<Self.columns {
            let x = (CGFloat(index) + 0.5) * pitch
            // 0 = live spectrum, 1 = settled into text.
            let settle = min(max((head - x) / blend, 0), 1)

            if settle < 1 {
                let i = Double(index)
                let wave = 0.55 * sin(time * 2.1 + i * 0.45)
                    + 0.30 * sin(time * 3.7 - i * 0.90)
                    + 0.15 * sin(time * 6.3 + i * 1.70)
                let edge = sin(Double.pi * (i + 0.5) / Double(Self.columns))
                let energy = (0.18 + 0.82 * (wave + 1) / 2) * (0.35 + 0.65 * edge)
                let height = max(3, (size.height - 6) * CGFloat(energy) * (1 - settle))
                let rect = CGRect(x: x - barWidth / 2, y: midY - height / 2, width: barWidth, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2),
                             with: .color(accent.opacity(Double(0.85 * (1 - settle)))))
            }

            if settle > 0 {
                for (row, offset) in Self.rows.enumerated() {
                    // Deterministic word gaps so the settled lines read like text.
                    let hash = (index &* 73 &+ row &* 151 &+ 17) % 11
                    if hash < 2 { continue }
                    let lineEnd = row == Self.rows.count - 1 ? 0.72 : 1.0
                    if x > size.width * lineEnd { continue }
                    let rect = CGRect(x: x - pitch / 2 + 0.5, y: midY + offset - 1.5,
                                      width: pitch - 1, height: 3)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.5),
                                 with: .color(accent.opacity(Double(0.45 * settle))))
                }
            }
        }

        // Scan head with a soft glow; it breathes gently while running.
        let pulse = 0.75 + 0.25 * sin(time * 4)
        let glow = CGRect(x: head - 10, y: 2, width: 20, height: size.height - 4)
        context.fill(Path(roundedRect: glow, cornerRadius: 10),
                     with: .linearGradient(Gradient(colors: [accent.opacity(0), accent.opacity(0.18 * pulse), accent.opacity(0)]),
                                           startPoint: CGPoint(x: glow.minX, y: 0),
                                           endPoint: CGPoint(x: glow.maxX, y: 0)))
        context.fill(Path(roundedRect: CGRect(x: head - 1, y: 0, width: 2, height: size.height), cornerRadius: 1),
                     with: .color(accent.opacity(0.9)))
        for capY in [CGFloat(0), size.height] {
            context.fill(Path(ellipseIn: CGRect(x: head - 3, y: capY - 3, width: 6, height: 6)),
                         with: .color(accent))
        }
    }
}
