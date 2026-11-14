import XCTest
@testable import ParakeetTranscriber

final class TranscriptExporterTests: XCTestCase {
    private let srt = "1\n00:00:01,000 --> 00:00:02,000\nHello\n\n2\n00:00:05,000 --> 00:00:06,000\nWorld\n"

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func testRenderPlainText() {
        XCTAssertEqual(TranscriptExporter.render(srt: srt, as: .plainText), "Hello\n\nWorld\n")
    }

    func testRenderWebVTT() {
        XCTAssertEqual(TranscriptExporter.render(srt: srt, as: .webVTT),
                       "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n\n00:00:05.000 --> 00:00:06.000\nWorld\n")
    }

    func testRenderEmptySRT() {
        XCTAssertEqual(TranscriptExporter.render(srt: "", as: .plainText), "")
        XCTAssertEqual(TranscriptExporter.render(srt: "", as: .webVTT), "WEBVTT\n")
    }

    func testDestinationAvoidsCollisions() {
        let srtURL = URL(fileURLWithPath: "/tmp/x/talk.srt")

        let free = TranscriptExporter.destination(for: srtURL, format: .plainText) { _ in false }
        XCTAssertEqual(free.lastPathComponent, "talk.txt")
        XCTAssertEqual(free.deletingLastPathComponent(), srtURL.deletingLastPathComponent())

        let once = TranscriptExporter.destination(for: srtURL, format: .plainText) {
            $0.lastPathComponent.hasSuffix("talk.txt")
        }
        XCTAssertEqual(once.lastPathComponent, "talk-2.txt")
        XCTAssertEqual(once.deletingLastPathComponent(), srtURL.deletingLastPathComponent())

        let twice = TranscriptExporter.destination(for: srtURL, format: .plainText) {
            $0.lastPathComponent.hasSuffix("talk.txt") || $0.lastPathComponent.hasSuffix("talk-2.txt")
        }
        XCTAssertEqual(twice.lastPathComponent, "talk-3.txt")
        XCTAssertEqual(twice.deletingLastPathComponent(), srtURL.deletingLastPathComponent())

        let vtt = TranscriptExporter.destination(for: srtURL, format: .webVTT) { _ in false }
        XCTAssertEqual(vtt.lastPathComponent, "talk.vtt")
    }

    func testExportWritesBesideSRTAndLeavesSRTUntouched() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let srtURL = directory.appendingPathComponent("talk.srt")
        try srt.write(to: srtURL, atomically: true, encoding: .utf8)
        let srtBytesBefore = try Data(contentsOf: srtURL)

        let first = try TranscriptExporter.export(srtURLs: [srtURL], as: .webVTT)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first[0].lastPathComponent, "talk.vtt")
        XCTAssertEqual(first[0].deletingLastPathComponent().path, directory.path)
        XCTAssertEqual(try String(contentsOf: first[0], encoding: .utf8),
                       "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n\n00:00:05.000 --> 00:00:06.000\nWorld\n")
        XCTAssertEqual(try Data(contentsOf: srtURL), srtBytesBefore)

        let second = try TranscriptExporter.export(srtURLs: [srtURL], as: .webVTT)
        XCTAssertEqual(second.map(\.lastPathComponent), ["talk-2.vtt"])
        XCTAssertEqual(try String(contentsOf: first[0], encoding: .utf8),
                       "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n\n00:00:05.000 --> 00:00:06.000\nWorld\n")
    }

    func testExportMissingFileThrows() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let missing = directory.appendingPathComponent("missing.srt")

        XCTAssertThrowsError(try TranscriptExporter.export(srtURLs: [missing], as: .plainText))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }
}
