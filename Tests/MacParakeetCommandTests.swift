import XCTest
@testable import ParakeetTranscriber

final class MacParakeetCommandTests: XCTestCase {
    private let cli = URL(fileURLWithPath: "/opt/homebrew/bin/macparakeet-cli")
    private let input = URL(fileURLWithPath: "/tmp/a file.mp3")
    private let output = URL(fileURLWithPath: "/tmp/transcripts")

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

}
