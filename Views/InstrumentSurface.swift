import SwiftUI

enum ParakeetPalette {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.08)
    static let surface = Color(red: 0.085, green: 0.095, blue: 0.115)
    static let magenta = Color(red: 0.73, green: 0.23, blue: 0.58)
    static let violet = Color(red: 0.43, green: 0.32, blue: 0.83)
    static let yellow = Color(red: 246.0 / 255.0, green: 216.0 / 255.0, blue: 24.0 / 255.0)
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.black : Color.secondary)
            .padding(.horizontal, 18)
            .frame(height: 34)
            .background(
                isEnabled ? ParakeetPalette.yellow : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct ProcessingWaveform: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24,
                                paused: reduceMotion || scenePhase != .active || !visible)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<9 {
                    let phase = Double(index) * 0.7
                    let wave = reduceMotion ? sin(phase) : sin(time * 3 + phase)
                    let height = 10 + 28 * (wave + 1) / 2
                    let rect = CGRect(x: Double(index) * 11 + 4,
                                      y: (size.height - height) / 2,
                                      width: 6, height: height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3),
                                 with: .linearGradient(
                                    Gradient(colors: [ParakeetPalette.yellow, ParakeetPalette.magenta]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: size.height)))
                }
            }
            .frame(width: 102, height: 42)
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .accessibilityHidden(true)
    }
}
