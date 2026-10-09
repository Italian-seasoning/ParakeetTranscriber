import Foundation

struct MacParakeetCommand: Equatable {
    let executableURL: URL
    let arguments: [String]

    static func make(
        cliURL: URL,
        files: [URL],
        outputDirectory: URL,
        model: TranscriptionModel,
        performance: PerformanceMode
    ) -> Self {
        var arguments = [
            "transcribe"
        ] + files.map(\.path) + [
            "--output-dir", outputDirectory.path,
            "--format", "srt",
            "--no-history",
            "--speaker-detection", "off"
        ] + modelArguments(for: model)

        if performance == .efficiency {
            arguments.insert(cliURL.path, at: 0)
            arguments.insert("-b", at: 0)
            return Self(
                executableURL: URL(fileURLWithPath: "/usr/sbin/taskpolicy"),
                arguments: arguments
            )
        }

        return Self(executableURL: cliURL, arguments: arguments)
    }

    private static func modelArguments(for model: TranscriptionModel) -> [String] {
        switch model {
        case .v3, .v2, .unified:
            ["--engine", "parakeet", "--parakeet-model", model.rawValue]
        case .nemotronEnglish:
            ["--engine", "nemotron", "--nemotron-model", "english-1120ms"]
        case .whisperTurbo:
            ["--engine", "whisper", "--language", "en"]
        }
    }
}

struct MacParakeetProgressParser {
    private var pending = Data()
    private var currentFile = 1
    private var totalFiles = 1
    private var localPercent: Double?
    private var lastReported: Double?

    static func progress(in output: String) -> Double? {
        var parser = Self()
        return parser.consume(Data(output.utf8))
    }

    mutating func consume(_ data: Data) -> Double? {
        pending.append(data)
        var start = pending.startIndex
        for index in pending.indices where pending[index] == 10 || pending[index] == 13 {
            readLine(String(decoding: pending[start..<index], as: UTF8.self)[...])
            start = pending.index(after: index)
        }
        pending.removeSubrange(pending.startIndex..<start)
        // CLI progress can end at a percent sign without a newline.
        readLine(String(decoding: pending, as: UTF8.self)[...])

        guard let localPercent else { return nil }
        let progress = min(max((Double(currentFile - 1) + localPercent / 100) / Double(totalFiles), 0), 1)
        guard progress != lastReported else { return nil }
        lastReported = progress
        return progress
    }

    private mutating func readLine(_ line: Substring) {
        if let batch = Self.batchPosition(in: line) {
            if batch.current != currentFile || batch.total != totalFiles {
                localPercent = 0
            }
            currentFile = batch.current
            totalFiles = batch.total
        }
        if let percent = Self.transcriptionPercent(in: line) {
            localPercent = percent
        }
    }

    private static func batchPosition(in line: Substring) -> (current: Int, total: Int)? {
        guard line.first == "[",
              let closeBracket = line.firstIndex(of: "]")
        else { return nil }

        let start = line.index(after: line.startIndex)
        let values = line[start..<closeBracket].split(separator: "/")
        guard values.count == 2,
              let current = Int(values[0]),
              let total = Int(values[1]),
              current > 0,
              total > 0,
              current <= total
        else { return nil }
        return (current, total)
    }

    private static func transcriptionPercent(in line: Substring) -> Double? {
        let marker = "Transcribing... "
        guard let markerRange = line.range(of: marker, options: .backwards) else { return nil }
        let digits = line[markerRange.upperBound...].prefix(while: \.isNumber)
        guard line[markerRange.upperBound...].dropFirst(digits.count).first == "%" else { return nil }
        return Double(digits)
    }
}

enum MacParakeetError: LocalizedError {
    case notInstalled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            "MacParakeet is not installed. Install it, then try again."
        case .failed(let message):
            message.isEmpty ? "Transcription failed." : message
        }
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var parser = MacParakeetProgressParser()

    func append(_ newData: Data) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        data.append(newData)
        return parser.consume(newData)
    }

    func text(appending finalData: Data) -> String {
        lock.lock()
        data.append(finalData)
        let text = String(decoding: data, as: UTF8.self)
        lock.unlock()
        return text
    }
}

final class MacParakeetService: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?

    func transcribe(
        files: [URL],
        outputDirectory: URL,
        model: TranscriptionModel,
        performance: PerformanceMode,
        onProgress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> [URL] {
        let cliURL = try locateCLI()
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let command = MacParakeetCommand.make(
            cliURL: cliURL,
            files: files,
            outputDirectory: outputDirectory,
            model: model,
            performance: performance
        )
        let task = Process()
        let pipe = Pipe()
        let outputBuffer = OutputBuffer()
        task.executableURL = command.executableURL
        task.arguments = command.arguments
        task.standardOutput = pipe
        task.standardError = pipe
        task.environment = ProcessInfo.processInfo.environment.merging([
            "MACPARAKEET_TELEMETRY": "0",
            "DO_NOT_TRACK": "1"
        ]) { _, appValue in appValue }
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            if let progress = outputBuffer.append(data) {
                onProgress(progress)
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                task.terminationHandler = { [weak self] process in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    let remainingData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = outputBuffer.text(appending: remainingData)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    self?.setProcess(nil)

                    if process.terminationStatus == 0 {
                        let urls = Self.transcriptURLs(in: output, outputDirectory: outputDirectory)
                        guard urls.count == files.count,
                              urls.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
                            continuation.resume(throwing: MacParakeetError.failed("The transcription finished, but its subtitle files could not be located. Check the output folder."))
                            return
                        }
                        onProgress(1)
                        continuation.resume(returning: urls)
                    } else {
                        continuation.resume(throwing: MacParakeetError.failed(output))
                    }
                }

                do {
                    setProcess(task)
                    try task.run()
                } catch {
                    setProcess(nil)
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            self.cancel()
        }
    }

    func cancel() {
        lock.lock()
        let runningProcess = process
        lock.unlock()
        if runningProcess?.isRunning == true {
            runningProcess?.terminate()
        }
    }

    static func transcriptURLs(in output: String, outputDirectory: URL) -> [URL] {
        let directory = outputDirectory.resolvingSymlinksInPath().standardizedFileURL.path
        return output.split(whereSeparator: \.isNewline).compactMap { line in
            let text = line.trimmingCharacters(in: .whitespaces)
            guard text.hasPrefix("→ ") else { return nil }
            let url = URL(fileURLWithPath: String(text.dropFirst(2)))
            guard url.pathExtension.lowercased() == "srt",
                  url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path == directory else { return nil }
            return url
        }
    }

    private func locateCLI() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/macparakeet-cli",
            "/usr/local/bin/macparakeet-cli"
        ]

        guard let path = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        })
        else { throw MacParakeetError.notInstalled }
        return URL(fileURLWithPath: path)
    }

    private func setProcess(_ process: Process?) {
        lock.lock()
        self.process = process
        lock.unlock()
    }
}
