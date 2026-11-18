import XCTest
@testable import ParakeetTranscriber

final class SubtitleConverterTests: XCTestCase {
    private let twoCueSRT = "1\n00:00:01,000 --> 00:00:02,500\nHello\n\n2\n00:00:03,000 --> 00:00:04,000\nWorld\n"

    func testParsesWellFormedSRT() {
        let result = SubtitleConverter.parseSRT(twoCueSRT)
        XCTAssertEqual(result.cues.count, 2)
        XCTAssertEqual(result.skippedBlocks, 0)
        XCTAssertEqual(result.cues[0], SubtitleConverter.Cue(index: 1, start: 1.0, end: 2.5, lines: ["Hello"]))
        XCTAssertEqual(result.cues[1], SubtitleConverter.Cue(index: 2, start: 3.0, end: 4.0, lines: ["World"]))
    }

    func testRendersWebVTT() {
        let cues = SubtitleConverter.parseSRT(twoCueSRT).cues
        XCTAssertEqual(SubtitleConverter.webVTT(from: cues),
                       "WEBVTT\n\n00:00:01.000 --> 00:00:02.500\nHello\n\n00:00:03.000 --> 00:00:04.000\nWorld\n")
    }

    func testMultiLineCueIsPreserved() {
        let cues = SubtitleConverter.parseSRT("1\n00:00:01,000 --> 00:00:02,000\nLine one\nLine two\n").cues
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].lines, ["Line one", "Line two"])
        XCTAssertEqual(SubtitleConverter.webVTT(from: cues),
                       "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nLine one\nLine two\n")
        XCTAssertEqual(SubtitleConverter.plainText(from: cues), "Line one Line two")
    }

    func testArrowInsideTextStaysText() {
        let result = SubtitleConverter.parseSRT("1\n00:00:01,000 --> 00:00:02,000\nA --> B\n")
        XCTAssertEqual(result.cues.count, 1)
        XCTAssertEqual(result.cues[0].lines, ["A --> B"])
        XCTAssertEqual(result.skippedBlocks, 0)
    }

    func testWindowsLineEndingsAndByteOrderMark() {
        let result = SubtitleConverter.parseSRT("\u{FEFF}1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n\r\n2\r\n00:00:03,000 --> 00:00:04,000\r\nWorld\r\n")
        XCTAssertEqual(result.cues.count, 2)
        XCTAssertEqual(result.skippedBlocks, 0)
        XCTAssertEqual(result.cues[0], SubtitleConverter.Cue(index: 1, start: 1.0, end: 2.0, lines: ["Hello"]))
        XCTAssertEqual(result.cues[1], SubtitleConverter.Cue(index: 2, start: 3.0, end: 4.0, lines: ["World"]))
    }

    func testEmptyInput() {
        for input in ["", "\n\n  \n"] {
            XCTAssertEqual(SubtitleConverter.parseSRT(input), SubtitleConverter.ParseResult(cues: [], skippedBlocks: 0))
        }
        XCTAssertEqual(SubtitleConverter.webVTT(from: []), "WEBVTT\n")
        XCTAssertEqual(SubtitleConverter.plainText(from: []), "")
    }

    func testMalformedBlocksAreSkippedAndCounted() {
        let result = SubtitleConverter.parseSRT("1\n00:00:01,000 --> 00:00:02,000\nGood\n\nnot a cue at all\n\n3\n00:00:05,000 --> 00:00:06,000\n\n4\n00:00:07,000 --> 00:00:08,000\nAlso good\n")
        XCTAssertEqual(result.cues.map(\.lines), [["Good"], ["Also good"]])
        XCTAssertEqual(result.cues.map(\.index), [1, 4])
        XCTAssertEqual(result.skippedBlocks, 2)
    }

    func testNonASCIITextSurvives() {
        let cues = SubtitleConverter.parseSRT("1\n00:00:01,000 --> 00:00:02,000\nCafé 日本語 😀\n").cues
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].lines, ["Café 日本語 😀"])
        XCTAssertTrue(SubtitleConverter.webVTT(from: cues).contains("Café 日本語 😀"))
        XCTAssertTrue(SubtitleConverter.plainText(from: cues).contains("Café 日本語 😀"))
    }

    func testPlainTextParagraphBreaksOnGapsOverTwoSeconds() {
        let cues = [
            SubtitleConverter.Cue(index: 1, start: 0, end: 1, lines: ["One."]),
            SubtitleConverter.Cue(index: 2, start: 1.5, end: 2, lines: ["Two."]),
            SubtitleConverter.Cue(index: 3, start: 4, end: 5, lines: ["Three."]),
            SubtitleConverter.Cue(index: 4, start: 7.5, end: 8, lines: ["Four."])
        ]
        XCTAssertEqual(SubtitleConverter.plainText(from: cues), "One. Two. Three.\n\nFour.")
    }

    func testMissingIndexAndShortFraction() {
        let cues = SubtitleConverter.parseSRT("01:02:03,5 --> 01:02:04.250\nNo index\n").cues
        XCTAssertEqual(cues.count, 1)
        XCTAssertEqual(cues[0].index, 1)
        XCTAssertEqual(cues[0].start, 3723.5, accuracy: 0.0001)
        XCTAssertEqual(cues[0].end, 3724.25, accuracy: 0.0001)
        XCTAssertEqual(SubtitleConverter.webVTT(from: cues), "WEBVTT\n\n01:02:03.500 --> 01:02:04.250\nNo index\n")
    }
}
