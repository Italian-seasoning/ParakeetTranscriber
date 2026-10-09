import AppKit
import XCTest
@testable import ParakeetTranscriber

final class MacParakeetCommandTests: XCTestCase {
    private let cli = URL(fileURLWithPath: "/opt/homebrew/bin/macparakeet-cli")
    private let input = URL(fileURLWithPath: "/tmp/a file.mp3")
    private let output = URL(fileURLWithPath: "/tmp/transcripts")

    func testModelSliderSnapsAndBoundsItsSelection() {
        for model in TranscriptionModel.allCases {
            XCTAssertEqual(TranscriptionModel.atSliderPosition(model.sliderPosition), model)
        }
        XCTAssertEqual(TranscriptionModel.atSliderPosition(1.6), .unified)
        XCTAssertEqual(TranscriptionModel.atSliderPosition(-100), .v3)
        XCTAssertEqual(TranscriptionModel.atSliderPosition(100), .whisperTurbo)
        XCTAssertEqual(TranscriptionModel.atSliderPosition(.nan), .v3)
    }

    func testFullSpeedUsesCLIAndSelectedModel() {
        let command = MacParakeetCommand.make(
            cliURL: cli,
            files: [input],
            outputDirectory: output,
            model: .unified,
            performance: .fullSpeed
        )

        XCTAssertEqual(command.executableURL, cli)
        XCTAssertEqual(command.arguments.first, "transcribe")
        XCTAssertTrue(command.arguments.contains("/tmp/a file.mp3"))
        XCTAssertEqual(
            Array(command.arguments.drop(while: { $0 != "--format" }).prefix(2)),
            ["--format", "srt"]
        )
        XCTAssertEqual(Array(command.arguments.suffix(2)), ["--parakeet-model", "unified"])
    }

    func testEfficiencyUsesTaskPolicyWithoutShellQuoting() {
        let command = MacParakeetCommand.make(
            cliURL: cli,
            files: [input],
            outputDirectory: output,
            model: .v3,
            performance: .efficiency
        )

        XCTAssertEqual(command.executableURL.path, "/usr/sbin/taskpolicy")
        XCTAssertEqual(Array(command.arguments.prefix(3)), [
            "-b", cli.path, "transcribe"
        ])
        XCTAssertTrue(command.arguments.contains("/tmp/a file.mp3"))
    }

    func testEnglishAlternativeModelsUseTheirOwnEngineFlags() {
        let nemotron = MacParakeetCommand.make(
            cliURL: cli,
            files: [input],
            outputDirectory: output,
            model: .nemotronEnglish,
            performance: .fullSpeed
        )
        let whisper = MacParakeetCommand.make(
            cliURL: cli,
            files: [input],
            outputDirectory: output,
            model: .whisperTurbo,
            performance: .fullSpeed
        )

        XCTAssertEqual(
            Array(nemotron.arguments.suffix(4)),
            ["--engine", "nemotron", "--nemotron-model", "english-1120ms"]
        )
        XCTAssertEqual(
            Array(whisper.arguments.suffix(4)),
            ["--engine", "whisper", "--language", "en"]
        )
    }

    func testProgressCombinesBatchPositionWithLatestCLIValue() throws {
        let output = """
        [1/4] first.wav
        Transcribing... 99%
        [2/4] second.wav
        Transcribing... 50%
        """

        XCTAssertEqual(
            try XCTUnwrap(MacParakeetProgressParser.progress(in: output)),
            0.375,
            accuracy: 0.0001
        )
    }

    func testProgressHandlesFragmentedLinesAndCarriageReturns() throws {
        var parser = MacParakeetProgressParser()
        XCTAssertEqual(parser.consume(Data("[1/2] first.wav\rTranscribing... 5".utf8)), 0)
        XCTAssertEqual(try XCTUnwrap(parser.consume(Data("0%\r".utf8))), 0.25)
        XCTAssertNil(parser.consume(Data("Transcribing... 50%\r".utf8)))
        XCTAssertEqual(try XCTUnwrap(parser.consume(Data("[2/2] second.wav\nTranscribing... 50%".utf8))), 0.75)
        XCTAssertEqual(try XCTUnwrap(parser.consume(Data("\rTranscribing... 100%\n".utf8))), 1)
    }

    @MainActor
    func testQueueDeduplicatesWithinAndAcrossBatches() {
        let store = TranscriptionStore()
        store.add([input, input, URL(fileURLWithPath: "/tmp/readme.txt")])
        store.add([input, URL(fileURLWithPath: "/tmp/second.wav")])
        XCTAssertEqual(store.files, [input, URL(fileURLWithPath: "/tmp/second.wav")])
        store.remove(input)
        XCTAssertEqual(store.files.count, 1)
    }

    func testSupportedMediaMatchesCLIFormats() {
        for ext in SupportedMedia.extensions {
            XCTAssertTrue(SupportedMedia.contains(URL(fileURLWithPath: "/tmp/input.\(ext.uppercased())")))
        }
        XCTAssertFalse(SupportedMedia.contains(URL(fileURLWithPath: "/tmp/input.aiff")))
        XCTAssertFalse(SupportedMedia.contains(URL(string: "https://example.com/input.wav")!))
    }

    func testOutputPathsUseCLIResultsAndStayInsideDestination() {
        let output = "  → /tmp/transcripts/a file-2.srt\n  → /tmp/elsewhere/other.srt\nDone: 1 transcribed → /tmp/transcripts"
        XCTAssertEqual(MacParakeetService.transcriptURLs(in: output, outputDirectory: self.output),
                       [self.output.appendingPathComponent("a file-2.srt")])
    }

    @MainActor
    func testFinderServiceQueuesClipboardFiles() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.writeObjects([input as NSURL, input as NSURL])
        let store = TranscriptionStore()
        let service = FinderServices(store: store)
        var error: NSString?
        service.transcribeFiles(pasteboard, userData: nil, error: &error)
        XCTAssertNil(error)
        XCTAssertEqual(store.files, [input])
        pasteboard.clearContents()
        service.transcribeFiles(pasteboard, userData: nil, error: &error)
        XCTAssertNotNil(error)
    }

}
