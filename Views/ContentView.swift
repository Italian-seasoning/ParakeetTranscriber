import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TranscriptionStore
    @State private var hoveredOption: String?

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
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
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
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }

    private var options: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Text(store.model.shortCode)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 42, height: 36)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPEECH MODEL")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.65))
                    Text(store.model.title)
                        .font(.system(size: 11, weight: .medium))
                    Slider(value: Binding(
                        get: { store.model.sliderPosition },
                        set: { store.model = .atSliderPosition($0) }
                    ), in: 0...Double(TranscriptionModel.allCases.count - 1), step: 1)
                    .controlSize(.small)
                    .labelsHidden()
                    .accessibilityLabel("Speech model")
                    .accessibilityValue(store.model.title)
                    .accessibilityHint(store.model.detail)
                    HStack(spacing: 0) {
                        ForEach(TranscriptionModel.allCases) { model in
                            Text(model.shortCode)
                                .foregroundStyle(store.model == model ? .white : .white.opacity(0.55))
                            if model != TranscriptionModel.allCases.last {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 290, height: 72)
            .background(optionSurface(tint: ParakeetPalette.magenta, isHovering: hoveredOption == "model"))
            .onHover { hoveredOption = $0 ? "model" : nil }
            .help(store.model.detail)
            HStack(spacing: 10) {
                Image(systemName: store.performance == .fullSpeed ? "bolt.fill" : "leaf")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("PERFORMANCE")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.65))
                    Text(store.performance.title)
                        .font(.system(size: 11, weight: .medium))
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
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 230, height: 72)
            .background(optionSurface(tint: ParakeetPalette.violet, isHovering: hoveredOption == "performance"))
            .onHover { hoveredOption = $0 ? "performance" : nil }
            .help(store.performance.detail)
            Spacer(minLength: 0)
            Text("SRT output")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .disabled(store.isRunning)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func optionSurface(tint: Color, isHovering: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        return shape
            .fill(tint.opacity(isHovering ? 0.15 : 0.09))
            .background(ParakeetPalette.surface, in: shape)
            .overlay(shape.strokeBorder(tint.opacity(isHovering ? 0.42 : 0.22)))
            .allowsHitTesting(false)
    }

    private var queue: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Files")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(store.files.count)")
                    .font(.caption.monospacedDigit())
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
            .padding(14)
            Divider()
            if store.files.isEmpty {
                DropZone(isRunning: store.isRunning, compact: false,
                         chooseFiles: store.chooseFiles, addFiles: store.add)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.files, id: \.standardizedFileURL) { file in
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
                                Button { store.remove(file) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.borderless)
                                .disabled(store.isRunning)
                                .help("Remove \(file.lastPathComponent)")
                                .accessibilityLabel("Remove \(file.lastPathComponent)")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            Divider().padding(.horizontal, 12)
                        }
                    }
                }
                DropZone(isRunning: store.isRunning, compact: true,
                         chooseFiles: store.chooseFiles, addFiles: store.add)
                    .frame(height: 52)
            }
        }
        .background(ParakeetPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08)))
        .padding(.trailing, 6)
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
                Button(action: store.copyTranscript) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .disabled(store.transcript.isEmpty || store.isRunning)
                .help("Copy transcript")
            }
            .padding(14)
            Divider()
            if store.transcript.isEmpty {
                VStack(spacing: 12) {
                    if store.isRunning {
                        ProcessingWaveform()
                    } else {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(ParakeetPalette.yellow.opacity(0.75))
                    }
                    Text(store.isRunning ? "Transcribing your files…" : "Add a recording to begin")
                        .font(.system(size: 16, weight: .medium))
                    Text(store.isRunning ? "You can keep working while Parakeet listens." : "Drop audio or video into the queue.\nChoose a model, then transcribe to SRT.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    if store.isRunning {
                        ProgressView(value: store.progress)
                            .frame(width: 180)
                        Text("\(Int((store.progress * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .accessibilityLabel("Transcript preview")
            }
        }
        .background(ParakeetPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.08)))
        .padding(.leading, 6)
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(store.lastError == nil ? Color.primary : Color.red)
                        .lineLimit(1)
                    Button(action: store.chooseOutputDirectory) {
                        Label("Save to: \(store.outputDirectory.lastPathComponent)", systemImage: "folder.badge.gearshape")
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
