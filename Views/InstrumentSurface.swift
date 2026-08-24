import AppKit
import SwiftUI

enum ParakeetPalette {
    static let background = Color(red: 0.018, green: 0.022, blue: 0.03)
    static let graphite = Color(red: 0.075, green: 0.08, blue: 0.095)
    static let magenta = Color(red: 187.0 / 255.0, green: 44.0 / 255.0, blue: 144.0 / 255.0)
    static let violet = Color(red: 103.0 / 255.0, green: 48.0 / 255.0, blue: 220.0 / 255.0)
    static let yellow = Color(red: 246.0 / 255.0, green: 216.0 / 255.0, blue: 24.0 / 255.0)
}

struct DottedField: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            for y in stride(from: spacing / 2, through: size.height, by: spacing) {
                for x in stride(from: spacing / 2, through: size.width, by: spacing) {
                    let dot = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(0.055)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct CursorGlowField: View {
    let position: UnitPoint
    let isVisible: Bool

    var body: some View {
        RadialGradient(
            colors: [
                .white.opacity(isVisible ? 0.055 : 0),
                ParakeetPalette.yellow.opacity(isVisible ? 0.03 : 0),
                ParakeetPalette.violet.opacity(isVisible ? 0.012 : 0),
                .clear
            ],
            center: position,
            startRadius: 24,
            endRadius: 360
        )
        .blendMode(.screen)
        .allowsHitTesting(false)
        .animation(
            .interactiveSpring(response: 0.32, dampingFraction: 0.9, blendDuration: 0.1),
            value: position
        )
        .animation(.easeOut(duration: 0.24), value: isVisible)
        .accessibilityHidden(true)
    }
}

enum GlassTileTone {
    case graphite
    case magenta
    case violet

    var renderName: String {
        switch self {
        case .graphite: "tile-graphite"
        case .magenta: "tile-magenta"
        case .violet: "tile-violet"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .graphite:
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.155, blue: 0.175),
                    ParakeetPalette.graphite
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .magenta:
            LinearGradient(
                colors: [
                    Color(red: 0.84, green: 0.29, blue: 0.71),
                    ParakeetPalette.magenta,
                    Color(red: 0.32, green: 0.08, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .violet:
            LinearGradient(
                colors: [
                    Color(red: 0.34, green: 0.25, blue: 0.88),
                    Color(red: 0.08, green: 0.09, blue: 0.31)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var glow: Color {
        switch self {
        case .graphite: .white
        case .magenta: ParakeetPalette.magenta
        case .violet: ParakeetPalette.violet
        }
    }
}

struct MouseReactiveGlassTile<Content: View>: View {
    let tone: GlassTileTone
    let cornerRadius: CGFloat
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pointer = UnitPoint.center
    @State private var tilt = CGSize.zero
    @State private var isHovering = false

    init(
        tone: GlassTileTone,
        cornerRadius: CGFloat = 38,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            ZStack {
                shape.fill(tone.gradient)

                if let render = NSImage(named: tone.renderName) {
                    Image(nsImage: render)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipShape(shape)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                RadialGradient(
                    colors: [
                        .white.opacity(isHovering ? 0.06 : 0),
                        tone.glow.opacity(isHovering ? 0.025 : 0),
                        .clear
                    ],
                    center: pointer,
                    startRadius: 22,
                    endRadius: max(proxy.size.width, proxy.size.height) * 1.15
                )
                .clipShape(shape)
                .allowsHitTesting(false)

                content
                    .padding(22)
            }
            .contentShape(shape)
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : -Double(tilt.height) * 0.32),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.7
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(tilt.width) * 0.42),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .shadow(
                color: .black.opacity(0.72),
                radius: 22,
                x: 6,
                y: 18
            )
            .shadow(
                color: tone.glow.opacity(isHovering ? 0.16 : 0.07),
                radius: isHovering ? 34 : 24,
                x: -2,
                y: 6
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let x = min(max(location.x / max(proxy.size.width, 1), 0), 1)
                    let y = min(max(location.y / max(proxy.size.height, 1), 0), 1)
                    let update = {
                        pointer = UnitPoint(x: x, y: y)
                        tilt = CGSize(width: (x - 0.5) * 2, height: (y - 0.5) * 2)
                        isHovering = true
                    }
                    if reduceMotion {
                        update()
                    } else {
                        withAnimation(
                            .interactiveSpring(response: 0.34, dampingFraction: 0.9, blendDuration: 0.12),
                            update
                        )
                    }
                case .ended:
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
                        isHovering = false
                        pointer = .center
                        tilt = .zero
                    }
                }
            }
        }
    }
}

struct SignalDial: View {
    let fileCount: Int
    let isRunning: Bool
    let progress: Double

    var body: some View {
        ZStack {
            Canvas { context, size in
                let count = 64
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerRadius = min(size.width, size.height) * 0.47
                let completedTicks = Int((clampedProgress * Double(count)).rounded(.down))

                for index in 0..<count {
                    let angle = (Double(index) / Double(count)) * Double.pi * 2 - Double.pi / 2
                    let isComplete = index < completedTicks
                    let innerRadius = outerRadius - (isComplete ? 14 : 9)
                    var tick = Path()
                    tick.move(to: CGPoint(
                        x: center.x + CGFloat(cos(angle)) * innerRadius,
                        y: center.y + CGFloat(sin(angle)) * innerRadius
                    ))
                    tick.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(angle)) * outerRadius,
                        y: center.y + CGFloat(sin(angle)) * outerRadius
                    ))
                    context.stroke(
                        tick,
                        with: .color(isComplete ? ParakeetPalette.yellow : .white.opacity(0.2)),
                        lineWidth: isComplete ? 2.5 : 1.2
                    )
                }
            }

            VStack(spacing: 4) {
                Text(primaryText)
                    .font(.system(size: 42, weight: .light, design: .monospaced))
                    .tracking(isRunning ? 1 : 4)
                Text(secondaryText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isRunning ? "Transcription in progress" : "\(fileCount) files ready")
        .accessibilityValue(isRunning ? "\(Int((clampedProgress * 100).rounded())) percent" : secondaryText)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var primaryText: String {
        if isRunning || clampedProgress >= 1 {
            return "\(Int((clampedProgress * 100).rounded()))%"
        }
        return fileCount == 0 ? "DROP" : "\(fileCount)"
    }

    private var secondaryText: String {
        if isRunning { return "TRANSCRIBING" }
        if clampedProgress >= 1 { return "COMPLETE" }
        if fileCount == 1 { return "FILE READY" }
        return fileCount > 1 ? "FILES READY" : "FILES HERE"
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isEnabled ? Color.black : Color.secondary)
            .padding(.horizontal, 20)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(isEnabled ? ParakeetPalette.yellow : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(.white.opacity(isEnabled ? 0.32 : 0.08))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .shadow(
                color: ParakeetPalette.yellow.opacity(isEnabled ? 0.28 : 0),
                radius: configuration.isPressed ? 8 : 16,
                y: 6
            )
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
