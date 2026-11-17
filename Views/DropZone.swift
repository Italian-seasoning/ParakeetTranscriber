import SwiftUI
import UniformTypeIdentifiers

struct DropZone: View {
    let isRunning: Bool
    let compact: Bool
    let chooseFiles: () -> Void
    let addFiles: ([URL]) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTargeted = false

    var body: some View {
        Button(action: chooseFiles) {
            VStack(spacing: compact ? 0 : 8) {
                if !compact {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(ParakeetPalette.yellow)
                        .padding(.bottom, 2)
                }
                Text(title)
                    .font(.system(size: compact ? 11 : 14, weight: .medium))
                if !compact {
                    HStack(spacing: 6) {
                        KeyCap("⌘V")
                        Text("paste copied files")
                        Text("·").foregroundStyle(.tertiary)
                        KeyCap("⌘O")
                        Text("browse")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                DotGrid()
                    .opacity(compact ? 0 : 1)
                    .padding(.horizontal, compact ? Space.inset : Space.gap)
                    .padding(.vertical, compact ? 6 : Space.gap)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .background {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isTargeted || reduceMotion)) { timeline in
                    // Dashes march only while a drag hovers; static otherwise.
                    let phase = isTargeted && !reduceMotion
                        ? -(timeline.date.timeIntervalSinceReferenceDate * 16).truncatingRemainder(dividingBy: 9)
                        : 0
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            ParakeetPalette.yellow.opacity(isTargeted ? 0.9 : 0.28),
                            style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: [5, 4], dashPhase: phase)
                        )
                        .background(
                            ParakeetPalette.yellow.opacity(isTargeted ? 0.07 : 0),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .padding(.horizontal, compact ? Space.inset : Space.gap)
                        .padding(.vertical, compact ? 6 : Space.gap)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .scaleEffect(isTargeted && !reduceMotion ? 1.01 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isTargeted)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            guard !isRunning else { return false }
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in addFiles([url]) }
                }
            }
            return !providers.isEmpty
        }
        .accessibilityLabel("Add audio or video files")
        .accessibilityHint("Choose files, drop files here, or paste copied files with Command V")
    }

    private var title: String {
        if isTargeted { return "Release to add files" }
        return compact ? "Drop more files, or paste with ⌘V" : "Drop audio or video"
    }
}

private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)),
                                 with: .color(.white.opacity(0.07)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
