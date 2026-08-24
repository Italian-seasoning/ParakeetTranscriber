import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TranscriptionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cursorPosition = UnitPoint.center
    @State private var isCursorInside = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ParakeetPalette.background
                    .ignoresSafeArea()
                DottedField()
                    .ignoresSafeArea()
                CursorGlowField(position: cursorPosition, isVisible: isCursorInside)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    header
                    workspace
                    actionDock
                }
                .padding(24)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let position = UnitPoint(
                        x: min(max(location.x / max(proxy.size.width, 1), 0), 1),
                        y: min(max(location.y / max(proxy.size.height, 1), 0), 1)
                    )
                    if reduceMotion {
                        cursorPosition = position
                        isCursorInside = true
                    } else {
                        withAnimation(
                            .interactiveSpring(response: 0.32, dampingFraction: 0.9, blendDuration: 0.1)
                        ) {
                            cursorPosition = position
                            isCursorInside = true
                        }
                    }
                case .ended:
                    withAnimation(.easeOut(duration: 0.24)) {
                        isCursorInside = false
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert(
            "Transcription Failed",
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
        HStack(spacing: 12) {
            Image(systemName: "waveform.path")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 38, height: 38)
                .background(ParakeetPalette.yellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("Parakeet")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                Text("LOCAL SPEECH WORKSTATION")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(store.isRunning ? ParakeetPalette.yellow : Color.green)
                    .frame(width: 7, height: 7)
                    .shadow(color: store.isRunning ? ParakeetPalette.yellow : .green, radius: 6)
                Text(store.isRunning ? "PROCESSING" : "ON DEVICE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.4)
            }
            .foregroundStyle(.secondary)
        }
        .frame(height: 40)
    }

    private var workspace: some View {
        HStack(spacing: 18) {
            MouseReactiveGlassTile(tone: .graphite) {
                VStack(alignment: .leading, spacing: 10) {
                    tileLabel("INPUT QUEUE", systemImage: "waveform")

                    DropZone(
                        fileCount: store.files.count,
                        isRunning: store.isRunning,
                        progress: store.progress,
                        chooseFiles: store.chooseFiles,
                        addFiles: store.add
                    )

                    if !store.files.isEmpty {
                        fileQueue
                    }
                }
            }
            .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 18) {
                modelTile
                performanceTile
            }
            .frame(width: 270)
        }
    }

    private var modelTile: some View {
        MouseReactiveGlassTile(tone: .magenta, cornerRadius: 36) {
            VStack(alignment: .leading, spacing: 10) {
                tileLabel("SPEECH MODEL", systemImage: "waveform.and.mic")
                Spacer(minLength: 2)
                Text(store.model.shortCode)
                    .font(.system(size: 46, weight: .light, design: .monospaced))
                    .tracking(3)
                Text(store.model.detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                Spacer(minLength: 2)
                optionMenu(title: store.model.title) {
                    ForEach(TranscriptionModel.allCases) { model in
                        Button {
                            store.model = model
                        } label: {
                            Label(
                                model.menuTitle,
                                systemImage: model == store.model ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                }
                .disabled(store.isRunning)
            }
        }
    }

    private var performanceTile: some View {
        MouseReactiveGlassTile(tone: .violet, cornerRadius: 36) {
            VStack(alignment: .leading, spacing: 10) {
                tileLabel("PERFORMANCE", systemImage: "bolt.fill")
                Spacer(minLength: 2)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(store.performance == .fullSpeed ? "MAX" : "ECO")
                        .font(.system(size: 42, weight: .light, design: .monospaced))
                        .tracking(2)
                    Text(store.performance == .fullSpeed ? "100%" : "LOW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(ParakeetPalette.yellow)
                }
                Text(store.performance.detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                Spacer(minLength: 2)
                optionMenu(title: store.performance.title) {
                    ForEach(PerformanceMode.allCases) { mode in
                        Button {
                            store.performance = mode
                        } label: {
                            if mode == store.performance {
                                Label(mode.title, systemImage: "checkmark")
                            } else {
                                Text(mode.title)
                            }
                        }
                    }
                }
                .disabled(store.isRunning)
            }
        }
    }

    private var fileQueue: some View {
        VStack(spacing: 0) {
            ForEach(store.files.prefix(2), id: \.standardizedFileURL) { file in
                HStack(spacing: 9) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(ParakeetPalette.yellow)
                    Text(file.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button {
                        store.remove(file)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                    }
                    .buttonStyle(.borderless)
                    .help("Remove file")
                    .disabled(store.isRunning)
                }
                .frame(height: 27)
            }

            if store.files.count > 2 {
                Text("+ \(store.files.count - 2) MORE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 8)
    }

    private var actionDock: some View {
        HStack(spacing: 14) {
            if store.isRunning {
                ProgressView(value: store.progress)
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(ParakeetPalette.yellow)
                    .accessibilityLabel("Transcription progress")
                    .accessibilityValue("\(Int((store.progress * 100).rounded())) percent")
            } else {
                Image(systemName: store.lastError == nil ? "waveform.path.ecg" : "exclamationmark.triangle.fill")
                    .foregroundStyle(store.lastError == nil ? ParakeetPalette.yellow : Color.red)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(store.status)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(store.lastError == nil ? Color.primary : Color.red)
                    .lineLimit(1)
                Button(action: store.chooseOutputDirectory) {
                    Text(store.outputDirectory.path(percentEncoded: false))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
                .disabled(store.isRunning)
                .help("Choose output folder")
            }

            Spacer(minLength: 12)

            dockButton("Show Output", systemImage: "folder", action: store.revealOutput)
                .disabled(store.isRunning)
            dockButton("Copy", systemImage: "doc.on.doc", action: store.copyTranscript)
                .disabled(store.transcript.isEmpty || store.isRunning)

            if store.isRunning {
                Button("Cancel", role: .cancel, action: store.cancel)
                    .controlSize(.large)
            } else {
                Button(action: store.start) {
                    Label("Transcribe", systemImage: "waveform")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!store.canTranscribe)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 76)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .shadow(color: .black.opacity(0.42), radius: 20, y: 10)
    }

    private func tileLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
            Spacer()
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.72))
    }

    private func optionMenu<Items: View>(
        title: String,
        @ViewBuilder items: () -> Items
    ) -> some View {
        Menu(content: items) {
            HStack {
                Text(title)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.16))
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private func dockButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .buttonStyle(.borderless)
        .controlSize(.large)
    }
}
