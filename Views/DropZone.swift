import SwiftUI
import UniformTypeIdentifiers

struct DropZone: View {
    let fileCount: Int
    let isRunning: Bool
    let progress: Double
    let chooseFiles: () -> Void
    let addFiles: ([URL]) -> Void

    @State private var isTargeted = false

    var body: some View {
        Button(action: chooseFiles) {
            VStack(spacing: 12) {
                SignalDial(fileCount: fileCount, isRunning: isRunning, progress: progress)
                    .frame(width: 220, height: 220)

                Text(prompt)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))

                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    ParakeetPalette.yellow.opacity(isTargeted ? 1 : 0),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .padding(4)
                .allowsHitTesting(false)
        )
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            loadURLs(from: providers)
            return true
        }
        .accessibilityLabel("Add audio or video files")
        .accessibilityHint("Click to choose files or drop files here")
    }

    private var prompt: String {
        if isTargeted { return "Release to add files" }
        if isRunning { return "Listening through your files" }
        if fileCount == 0 { return "Drop audio or video" }
        return fileCount == 1 ? "One file is ready" : "\(fileCount) files are ready"
    }

    private var detail: String {
        isRunning ? "PRIVATE · ON DEVICE" : "OR CLICK TO CHOOSE"
    }

    private func loadURLs(from providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data,
                      let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }
                Task { @MainActor in addFiles([url]) }
            }
        }
    }
}
