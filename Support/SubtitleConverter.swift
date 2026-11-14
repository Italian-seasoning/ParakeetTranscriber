import Foundation

enum SubtitleConverter {
    struct Cue: Equatable {
        var index: Int
        var start: TimeInterval
        var end: TimeInterval
        var lines: [String]
    }

    struct ParseResult: Equatable {
        var cues: [Cue]
        var skippedBlocks: Int
    }

    private static let timingPattern = try! NSRegularExpression(
        pattern: #"^(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s+-->\s+(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})$"#
    )

    static func parseSRT(_ text: String) -> ParseResult {
        var normalized = text
        if normalized.unicodeScalars.first == "\u{FEFF}" {
            normalized = String(String.UnicodeScalarView(normalized.unicodeScalars.dropFirst()))
        }
        normalized = normalized
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var blocks: [[String]] = []
        var current: [String] = []
        for line in normalized.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !current.isEmpty {
                    blocks.append(current)
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty {
            blocks.append(current)
        }

        var cues: [Cue] = []
        var skipped = 0
        for block in blocks {
            let index: Int
            let timing: (start: TimeInterval, end: TimeInterval)
            let textStart: Int
            if let parsed = parseTiming(block[0]) {
                index = cues.count + 1
                timing = parsed
                textStart = 1
            } else if block.count > 1,
                      let number = Int(block[0].trimmingCharacters(in: .whitespacesAndNewlines)),
                      let parsed = parseTiming(block[1]) {
                index = number
                timing = parsed
                textStart = 2
            } else {
                skipped += 1
                continue
            }

            let textLines = Array(block[textStart...])
            guard !textLines.isEmpty else {
                skipped += 1
                continue
            }
            cues.append(Cue(index: index, start: timing.start, end: timing.end, lines: textLines))
        }

        return ParseResult(cues: cues, skippedBlocks: skipped)
    }

    static func webVTT(from cues: [Cue]) -> String {
        var output = "WEBVTT\n"
        for cue in cues {
            output += "\n\(timestamp(cue.start)) --> \(timestamp(cue.end))\n"
            output += cue.lines.joined(separator: "\n") + "\n"
        }
        return output
    }

    static func plainText(from cues: [Cue], paragraphGap: TimeInterval = 2) -> String {
        var result = ""
        var previous: Cue?
        for cue in cues {
            let text = cue.lines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !text.isEmpty else { continue }
            if let previous {
                result += (cue.start - previous.end > paragraphGap) ? "\n\n" : " "
            }
            result += text
            previous = cue
        }
        return result
    }

    private static func parseTiming(_ line: String) -> (start: TimeInterval, end: TimeInterval)? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let nsLine = trimmed as NSString
        guard let match = timingPattern.firstMatch(
            in: trimmed,
            range: NSRange(location: 0, length: nsLine.length)
        ), match.numberOfRanges == 9 else { return nil }

        func group(_ number: Int) -> String {
            nsLine.substring(with: match.range(at: number))
        }

        func seconds(from first: Int) -> TimeInterval? {
            guard let hours = Int(group(first)),
                  let minutes = Int(group(first + 1)),
                  let secs = Int(group(first + 2)),
                  let fraction = Int((group(first + 3) + "00").prefix(3))
            else { return nil }
            return TimeInterval(hours * 3600 + minutes * 60 + secs) + TimeInterval(fraction) / 1000
        }

        guard let start = seconds(from: 1), let end = seconds(from: 5) else { return nil }
        return (start, end)
    }

    private static func timestamp(_ seconds: TimeInterval) -> String {
        let milliseconds = Int((seconds * 1000).rounded())
        let hours = milliseconds / 3_600_000
        let minutes = (milliseconds / 60_000) % 60
        let secs = (milliseconds / 1000) % 60
        let millis = milliseconds % 1000
        return String(format: "%02ld:%02ld:%02ld.%03ld", hours, minutes, secs, millis)
    }
}
