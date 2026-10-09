import AppKit
import Foundation

@MainActor
final class TranscriptionStore: ObservableObject {
    @Published var files: [URL] = []
    @Published var model: TranscriptionModel = .v3
    @Published var performance: PerformanceMode = .fullSpeed
    @Published var outputDirectory: URL
    @Published private(set) var isRunning = false
    @Published private(set) var progress = 0.0
    @Published private(set) var status = "Drop audio or video files to begin."
    @Published private(set) var lastError: String?
    @Published private(set) var transcript = ""
    @Published private(set) var transcriptURLs: [URL] = []

    private let service = MacParakeetService()
    private var transcriptionTask: Task<Void, Never>?

    init() {
        outputDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Parakeet Transcripts", isDirectory: true)
    }

    var canTranscribe: Bool {
        !files.isEmpty && !isRunning
    }

    func add(_ urls: [URL]) {
        guard !isRunning else { return }
        let validFiles = urls.filter(SupportedMedia.contains)
        var existing = Set(files.map(\.standardizedFileURL))
        files.append(contentsOf: validFiles.filter {
            existing.insert($0.standardizedFileURL).inserted
        })
        progress = 0
        status = files.isEmpty
            ? "Choose audio or video files."
            : "\(files.count) \(files.count == 1 ? "file" : "files") ready."
    }

    func remove(_ url: URL) {
        guard !isRunning else { return }
        files.removeAll { $0.standardizedFileURL == url.standardizedFileURL }
        progress = 0
        status = files.isEmpty
            ? "Drop audio or video files to begin."
            : "\(files.count) \(files.count == 1 ? "file" : "files") ready."
    }

    func chooseFiles() {
        guard !isRunning else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = SupportedMedia.contentTypes
        guard panel.runModal() == .OK else { return }
        add(panel.urls)
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    func addClipboardFiles() {
        guard !isRunning else { return }
        let urls = Self.fileURLs(from: .general).filter(SupportedMedia.contains)
        guard !urls.isEmpty else {
            status = "Copy audio or video files in Finder, then add them with ⇧⌘V."
            return
        }
        add(urls)
    }

    func chooseOutputDirectory() {
        guard !isRunning else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        outputDirectory = url
    }

    func start() {
        guard canTranscribe else { return }
        isRunning = true
        progress = 0
        lastError = nil
        transcript = ""
        transcriptURLs = []
        status = "Transcribing \(files.count) \(files.count == 1 ? "file" : "files")…"

        let queuedFiles = files
        let selectedModel = model
        let selectedPerformance = performance
        let destination = outputDirectory

        transcriptionTask = Task { [self] in
            do {
                let outputURLs = try await service.transcribe(
                    files: queuedFiles,
                    outputDirectory: destination,
                    model: selectedModel,
                    performance: selectedPerformance,
                    onProgress: { [weak self] value in
                        Task { @MainActor in
                            guard let self, self.isRunning else { return }
                            self.progress = max(self.progress, value)
                        }
                    }
                )
                progress = 1
                transcript = try outputURLs.map {
                    try String(contentsOf: $0, encoding: .utf8)
                }.joined(separator: "\n\n")
                transcriptURLs = outputURLs
                status = transcript.isEmpty
                    ? "Transcription complete."
                    : "Transcription complete. Ready to copy."
            } catch {
                progress = 0
                if Task.isCancelled {
                    status = "Transcription cancelled."
                } else {
                    lastError = error.localizedDescription
                    status = "Transcription failed."
                }
            }
            isRunning = false
            transcriptionTask = nil
        }
    }

    func cancel() {
        transcriptionTask?.cancel()
        service.cancel()
        status = "Cancelling…"
    }

    func revealOutput() {
        if !transcriptURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(transcriptURLs)
            return
        }
        try? FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(outputDirectory)
    }

    func copyTranscript() {
        guard !transcript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        status = "Transcript copied to clipboard."
    }

    func dismissError() {
        lastError = nil
    }
}
