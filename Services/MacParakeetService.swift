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
    static func progress(in output: String) -> Double? {
        var currentFile = 1
        var totalFiles = 1
        var localPercent: Double?

        for line in output.split(whereSeparator: \.isNewline) {
            if let batch = batchPosition(in: line) {
                currentFile = batch.current
                totalFiles = batch.total
                localPercent = 0
            }
            if let percent = transcriptionPercent(in: line) {
                localPercent = percent
            }
        }

        guard let localPercent else { return nil }
        let completedFiles = Double(max(currentFile - 1, 0))
        let progress = (completedFiles + localPercent / 100) / Double(max(totalFiles, 1))
        return min(max(progress, 0), 1)
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
              total > 0
        else { return nil }
        return (current, total)
    }

    private static func transcriptionPercent(in line: Substring) -> Double? {
        let marker = "Transcribing... "
        guard let markerRange = line.range(of: marker, options: .backwards) else { return nil }
        let digits = line[markerRange.upperBound...].prefix(while: \.isNumber)
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

    func appendAndRead(_ newData: Data) -> String {
        lock.lock()
        data.append(newData)
        let text = String(decoding: data, as: UTF8.self)
        lock.unlock()
        return text
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
        let transcriptURLs = files.map {
            outputDirectory
                .appendingPathComponent($0.deletingPathExtension().lastPathComponent)
                .appendingPathExtension("srt")
        }

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
            let output = outputBuffer.appendAndRead(data)
            if let progress = MacParakeetProgressParser.progress(in: output) {
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
                        onProgress(1)
                        continuation.resume(returning: transcriptURLs.filter {
                            FileManager.default.fileExists(atPath: $0.path)
                        })
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
