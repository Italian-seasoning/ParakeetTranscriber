import SwiftUI
import UniformTypeIdentifiers

struct DropZone: View {
    let isRunning: Bool
    let compact: Bool
    let chooseFiles: () -> Void
    let addFiles: ([URL]) -> Void
    @State private var isTargeted = false

    var body: some View {
        Button(action: chooseFiles) {
            VStack(spacing: 10) {
                if !compact {
                    Image(systemName: "plus.square.dashed")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(ParakeetPalette.yellow)
                }
                Text(isTargeted ? "Release to add files" : compact ? "Drop more files or browse" : "Drop audio or video")
                    .font(.system(size: compact ? 11 : 13, weight: .medium))
                if !compact {
                    Text("or click to browse  ·  ⌘O")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .background(ParakeetPalette.yellow.opacity(isTargeted ? 0.08 : 0))
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
        .accessibilityHint("Choose files or drop files here")
    }
}
