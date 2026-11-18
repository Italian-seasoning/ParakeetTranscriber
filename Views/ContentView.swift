import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TranscriptionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false

    /// Short ease for state changes; nil when Reduce Motion is on.
    private var quick: Animation? { reduceMotion ? nil : .easeOut(duration: 0.18) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            options
            HSplitView {
                queue
                    .frame(minWidth: 230, idealWidth: 270, maxWidth: 320)
                transcript
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, Space.margin)
            .padding(.bottom, Space.margin)
            footer
        }
        .background(ParakeetPalette.background)
        .preferredColorScheme(.dark)
        .tint(ParakeetPalette.yellow)
        .alert(
            "Transcription failed",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "Unknown error")
        }
    }

    private func copyTranscript() {
        guard !store.transcript.isEmpty else { return }
        store.copyTranscript()
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
            Text("Parakeet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text("Transcriber")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Label("On device", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Space.margin)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var options: some View {
        HStack(alignment: .top, spacing: Space.gap) {
            optionPanel {
                HStack(spacing: 6) {
                    Text("Speech model")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(store.model.downloadSize)
                        .foregroundStyle(ParakeetPalette.yellow.opacity(0.85))
                }
                .font(.system(size: 11, design: .monospaced))
                Text(store.model.title)
                    .font(.system(size: 14, weight: .semibold))
                Slider(value: Binding(
                    get: { store.model.sliderPosition },
                    set: { store.model = .atSliderPosition($0) }
                ), in: 0...Double(TranscriptionModel.allCases.count - 1), step: 1)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel("Speech model")
                .accessibilityValue(store.model.title)
                .accessibilityHint("\(store.model.detail), \(store.model.downloadSize) download")
                HStack(spacing: 0) {
                    ForEach(TranscriptionModel.allCases) { model in
                        Text(model.shortCode)
                            .foregroundStyle(store.model == model ? Color.primary : Color.secondary.opacity(0.8))
                        if model != TranscriptionModel.allCases.last {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .accessibilityHidden(true)
            }
            .help("\(store.model.detail) · \(store.model.downloadSize) download")
            optionPanel {
                HStack(spacing: 6) {
                    Text("Performance")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Image(systemName: store.performance == .fullSpeed ? "bolt.fill" : "leaf")
                        .foregroundStyle(store.performance == .fullSpeed ? ParakeetPalette.yellow : Color.secondary)
                }
                .font(.system(size: 11, design: .monospaced))
                Text(store.performance.title)
                    .font(.system(size: 14, weight: .semibold))
                Slider(value: Binding(
                    get: { store.performance == .fullSpeed ? 1 : 0 },
                    set: { store.performance = $0 < 0.5 ? .efficiency : .fullSpeed }
                ), in: 0...1, step: 1)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel("Performance")
                .accessibilityValue(store.performance.title)
                .accessibilityHint(store.performance.detail)
                HStack {
                    Text("Efficiency")
                    Spacer()
                    Text("Full speed")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary.opacity(0.8))
                .accessibilityHidden(true)
            }
            .frame(width: 230)
            .help(store.performance.detail)
        }
        .disabled(store.isRunning)
        .padding(.horizontal, Space.margin)
        .padding(.vertical, Space.gap)
    }

    private func optionPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(Space.inset)
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .leading)
        .background(ParakeetPalette.surface, in: RoundedRectangle(cornerRadius: Space.radius))
        .overlay(RoundedRectangle(cornerRadius: Space.radius).strokeBorder(.white.opacity(0.08)))
    }

    private var queue: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Files")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(store.files.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Choose files…", action: store.chooseFiles)
                    Button("Add clipboard files", action: store.addClipboardFiles)
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .disabled(store.isRunning)
                .help("Add files (⌘O)")
                .accessibilityLabel("Add files")
            }
            .padding(Space.inset)
            Divider()
            if store.files.isEmpty {
                DropZone(isRunning: store.isRunning, compact: false,
                         chooseFiles: store.chooseFiles, addFiles: store.add)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.files, id: \.standardizedFileURL) { file in
                            FileRow(file: file, isRunning: store.isRunning) { store.remove(file) }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(quick, value: store.files)
                }
                DropZone(isRunning: store.isRunning, compact: true,
                         chooseFiles: store.chooseFiles, addFiles: store.add)
                    .frame(height: 52)
            }
        }
        .background(ParakeetPalette.surface, in: RoundedRectangle(cornerRadius: Space.radius))
        .overlay(RoundedRectangle(cornerRadius: Space.radius).strokeBorder(.white.opacity(0.08)))
        .padding(.trailing, Space.gap / 2)
    }

    private var transcript: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Transcript")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                ShareLink(items: store.transcriptURLs) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(store.transcriptURLs.isEmpty || store.isRunning)
                .help("Share subtitle files")
                .accessibilityLabel("Share subtitle files")
                Menu {
                    ForEach(TranscriptExporter.Format.allCases, id: \.self) { format in
                        Button(format.menuTitle) { store.exportTranscripts(as: format) }
                    }
                    Divider()
                    Button("Copy text only") { store.copyTranscriptTextOnly() }
                } label: {
                    Image(systemName: "arrow.down.doc")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(store.transcriptURLs.isEmpty || store.isRunning)
                .help("Export as text or WebVTT")
                .accessibilityLabel("Export transcript")
                Button(action: copyTranscript) {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(minWidth: 64, alignment: .trailing)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(copied ? Color.green : ParakeetPalette.yellow)
                .animation(quick, value: copied)
                .disabled(store.transcript.isEmpty || store.isRunning)
                .help("Copy transcript")
            }
            .padding(Space.inset)
            Divider()
            if store.transcript.isEmpty {
                VStack(spacing: 10) {
                    if store.isRunning {
                        ProcessingWaveform(progress: store.progress)
                            .padding(.bottom, 6)
                        Text("Transcribing your files…")
                            .font(.system(size: 15, weight: .medium))
                        Text("You can keep working while Parakeet listens.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        ProgressView(value: store.progress)
                            .frame(width: 180)
                            .padding(.top, 4)
                        Text("\(Int((store.progress * 100).rounded()))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Your transcript appears here")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("Add a recording, then choose Transcribe.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                ScrollView {
                    Text(store.transcript)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
                .frame(maxHeight: .infinity)
                .transition(.opacity)
                .accessibilityLabel("Transcript preview")
            }
        }
        .animation(quick, value: store.transcript.isEmpty)
        .background(ParakeetPalette.surface, in: RoundedRectangle(cornerRadius: Space.radius))
        .overlay(RoundedRectangle(cornerRadius: Space.radius).strokeBorder(.white.opacity(0.08)))
        .padding(.leading, Space.gap / 2)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if store.isRunning {
                ProgressView(value: store.progress)
                    .progressViewStyle(.linear)
                    .accessibilityLabel("Transcription progress")
            } else {
                Divider()
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(store.status)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(store.lastError == nil ? Color.primary : Color.red)
                        .lineLimit(1)
                        .id(store.status)
                        .transition(.opacity)
                        .animation(quick, value: store.status)
                    Button(action: store.chooseOutputDirectory) {
                        Label("Saves SRT to \(store.outputDirectory.lastPathComponent)", systemImage: "folder.badge.gearshape")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isRunning)
                    .help("Choose output folder: \(store.outputDirectory.path)")
                    .accessibilityLabel("Choose output folder")
                }
                Spacer(minLength: 4)
                Button(action: store.revealOutput) {
                    Label("Open folder", systemImage: "folder")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12))
                if store.isRunning {
                    Button("Cancel", role: .cancel, action: store.cancel)
                        .keyboardShortcut(.cancelAction)
                } else {
                    Button(action: store.start) {
                        Label("Transcribe", systemImage: "waveform")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!store.canTranscribe)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, Space.margin)
            .padding(.vertical, Space.gap)
        }
    }
}

private struct FileRow: View {
    let file: URL
    let isRunning: Bool
    let remove: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.waveform")
                    .foregroundStyle(ParakeetPalette.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(file.pathExtension.uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 2)
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .opacity(hovering && !isRunning ? 1 : 0.45)
                .disabled(isRunning)
                .help("Remove \(file.lastPathComponent)")
                .accessibilityLabel("Remove \(file.lastPathComponent)")
            }
            .padding(.horizontal, Space.inset)
            .padding(.vertical, 10)
            .background(.white.opacity(hovering ? 0.04 : 0))
            Divider().padding(.horizontal, Space.inset)
        }
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
