import XCTest
import MLXAudioSTT
@testable import Voxt

final class SenseVoiceMetadataTests: XCTestCase {
    func testFromOutputPreservesAllSegmentsAndAggregatesDominantMetadata() {
        let output = STTOutput(
            text: "ignored top-level text",
            segments: [
                [
                    "text": " first segment ",
                    "language": "en",
                    "emotion": "happy",
                    "event": "speech",
                ],
                [
                    "text": "second segment",
                    "language": "en",
                    "emotion": " calm ",
                    "event": "speech",
                ],
                [
                    "text": " third segment ",
                    "language": "ja",
                    "emotion": "happy",
                    "event": "music",
                ],
            ],
            language: "en"
        )

        let metadata = SenseVoiceTranscriptMetadata.fromOutput(
            output,
            startSeconds: 0,
            endSeconds: 9,
            usedVADSegmentation: false
        )

        XCTAssertEqual(metadata?.language, "en")
        XCTAssertEqual(metadata?.emotion, "happy")
        XCTAssertEqual(metadata?.event, "speech")
        XCTAssertEqual(metadata?.segments.count, 3)
        XCTAssertEqual(metadata?.segments.map(\.text), ["first segment", "second segment", "third segment"])
        XCTAssertEqual(metadata?.segments.map(\.language), ["en", "en", "ja"])
        XCTAssertEqual(metadata?.segments.map(\.emotion), ["happy", "calm", "happy"])
        XCTAssertEqual(metadata?.segments.map(\.event), ["speech", "speech", "music"])
    }

    func testFromOutputUsesFallbackLanguageAndExplicitSegmentTimingWhenPresent() throws {
        let output = STTOutput(
            text: "overall transcript",
            segments: [
                [
                    "text": "alpha",
                    "startSeconds": 1.5,
                    "endSeconds": 2.75,
                ],
                [
                    "text": "beta",
                    "startSeconds": "3.0",
                    "endSeconds": "4.25",
                    "emotion": "focused",
                ],
            ],
            language: "zh"
        )

        let metadata = try XCTUnwrap(
            SenseVoiceTranscriptMetadata.fromOutput(
                output,
                startSeconds: 0,
                endSeconds: 5,
                usedVADSegmentation: true
            )
        )

        XCTAssertEqual(metadata.language, "zh")
        XCTAssertEqual(metadata.emotion, "focused")
        XCTAssertTrue(metadata.usedVADSegmentation)
        XCTAssertEqual(metadata.segments[0].startSeconds, 1.5, accuracy: 0.0001)
        XCTAssertEqual(metadata.segments[0].endSeconds, 2.75, accuracy: 0.0001)
        XCTAssertEqual(metadata.segments[0].language, "zh")
        XCTAssertEqual(metadata.segments[1].startSeconds, 3.0, accuracy: 0.0001)
        XCTAssertEqual(metadata.segments[1].endSeconds, 4.25, accuracy: 0.0001)
        XCTAssertEqual(metadata.segments[1].language, "zh")
        XCTAssertEqual(metadata.segments[1].emotion, "focused")
    }

    func testMLXConfigurationSummaryOmitsPresetForSenseVoice() {
        let tuning = MLXLocalTuningSettings(
            preset: .accuracyFirst,
            senseVoiceUseITN: true
        )

        XCTAssertEqual(
            MLXConfigurationSummarySupport.summary(
                for: "mlx-community/SenseVoiceSmall",
                tuning: tuning
            ),
            AppLocalization.localizedString("ITN On")
        )
    }
}
