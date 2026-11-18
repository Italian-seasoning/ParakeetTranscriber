import Foundation

enum TranscriptExporter {
    enum Format: String, CaseIterable {
        case plainText, webVTT

        var fileExtension: String {
            switch self {
            case .plainText: "txt"
            case .webVTT: "vtt"
            }
        }

        var menuTitle: String {
            switch self {
            case .plainText: "Plain text (.txt)"
            case .webVTT: "WebVTT (.vtt)"
            }
        }
    }

    static func render(srt: String, as format: Format) -> String {
        let cues = SubtitleConverter.parseSRT(srt).cues
        switch format {
        case .plainText:
            let text = SubtitleConverter.plainText(from: cues)
            return text.isEmpty ? "" : text + "\n"
        case .webVTT:
            return SubtitleConverter.webVTT(from: cues)
        }
    }

    static func destination(for srtURL: URL, format: Format, fileExists: (URL) -> Bool) -> URL {
        let folder = srtURL.deletingLastPathComponent()
        let baseName = srtURL.deletingPathExtension().lastPathComponent
        let fileExtension = format.fileExtension
        var number = 1
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        while fileExists(candidate) {
            number += 1
            candidate = folder.appendingPathComponent("\(baseName)-\(number)").appendingPathExtension(fileExtension)
        }
        return candidate
    }

    static func export(srtURLs: [URL], as format: Format) throws -> [URL] {
        try srtURLs.map { srtURL in
            let srt = try String(contentsOf: srtURL, encoding: .utf8)
            let output = destination(for: srtURL, format: format) {
                FileManager.default.fileExists(atPath: $0.path)
            }
            try render(srt: srt, as: format).write(to: output, atomically: true, encoding: .utf8)
            return output
        }
    }
}
