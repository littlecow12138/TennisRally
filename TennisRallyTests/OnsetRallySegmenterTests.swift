import XCTest
@testable import TennisRally

final class OnsetRallySegmenterTests: XCTestCase {
    func testClusterGroupsPeaksSeparatedByGap() {
        let segmenter = OnsetRallySegmenter()
        // Two rallies: dense hits, then a long silence, then more hits.
        let peaks: [Double] = [
            10.0, 10.8, 11.6, 12.4, 13.2, 14.0,
            20.0, 20.9, 21.7, 22.5, 23.4, 24.2
        ]
        let segments = segmenter.cluster(peaks: peaks, duration: 40)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].start, 9.75, accuracy: 0.01)
        XCTAssertEqual(segments[0].end, 14.4, accuracy: 0.01)
        XCTAssertEqual(segments[1].start, 19.75, accuracy: 0.01)
        XCTAssertEqual(segments[1].end, 24.6, accuracy: 0.01)
    }

    func testRejectBounceLikeRegular() {
        let segmenter = OnsetRallySegmenter()
        let f = OnsetRallySegmenter.Features(
            n: 8,
            dur: 6.0,
            rate: 1.3,
            ioiCV: 0.2,
            ioiMed: 0.55,
            maxIOI: 0.9,
            fracBounceIOI: 0.8,
            fracGT1: 0.0
        )
        XCTAssertEqual(segmenter.reject(f, gapToNext: nil), "bounce_like_regular")
    }

    func testRejectKeepsVariedRally() {
        let segmenter = OnsetRallySegmenter()
        let f = OnsetRallySegmenter.Features(
            n: 10,
            dur: 12.0,
            rate: 0.85,
            ioiCV: 0.9,
            ioiMed: 1.1,
            maxIOI: 2.4,
            fracBounceIOI: 0.3,
            fracGT1: 0.4
        )
        XCTAssertNil(segmenter.reject(f, gapToNext: nil))
    }

    func testSyntheticImpulseTrainProducesAtLeastOneSegment() {
        let sr = 16_000
        // Build ~20s of near-silence with two rally-like burst windows.
        var samples = [Float](repeating: 0, count: sr * 25)
        func addBurst(startSec: Double, hits: Int, ioi: Double) {
            for i in 0..<hits {
                let t = startSec + Double(i) * ioi
                let idx = Int(t * Double(sr))
                guard idx + 40 < samples.count else { continue }
                // Short broadband click.
                for j in 0..<40 {
                    let env = sin(Float(j) / 40.0 * .pi)
                    samples[idx + j] += env * (j % 2 == 0 ? 0.9 : -0.9)
                }
            }
        }
        // Varied IOI (~0.7–1.4s) so bounce filters do not drop it.
        addBurst(startSec: 5.0, hits: 10, ioi: 0.95)
        // Nudge a few later hits for irregular gaps.
        addBurst(startSec: 5.0 + 10 * 0.95 + 1.3, hits: 4, ioi: 1.15)
        addBurst(startSec: 18.0, hits: 8, ioi: 1.05)

        let segments = OnsetRallySegmenter().segment(samples: samples, sampleRate: sr)
        XCTAssertGreaterThanOrEqual(segments.count, 1, "expected ≥1 rally from synthetic impulses, got \(segments)")
        if let first = segments.first {
            XCTAssertGreaterThanOrEqual(first.end - first.start, 3.5)
        }
    }

    func testRealFixtureAudioProducesRallies() throws {
        guard let url = Bundle(for: OnsetRallySegmenterTests.self).url(
            forResource: "IMG_4257_2_first120s",
            withExtension: "wav"
        ) else {
            XCTFail("missing fixture IMG_4257_2_first120s.wav")
            return
        }
        let (samples, sr) = try Self.readWavPCM16Mono(url: url)
        XCTAssertEqual(sr, 16_000)
        let segments = OnsetRallySegmenter().segment(samples: samples, sampleRate: sr)
        XCTAssertGreaterThanOrEqual(segments.count, 1, "expected ≥1 rally on fixture, got \(segments.count)")
        for seg in segments {
            XCTAssertGreaterThanOrEqual(seg.end - seg.start, 3.0)
            XCTAssertLessThanOrEqual(seg.end, Double(samples.count) / Double(sr) + 0.5)
        }
    }

    private static func readWavPCM16Mono(url: URL) throws -> ([Float], Int) {
        let data = try Data(contentsOf: url)
        guard data.count > 44 else { throw NSError(domain: "wav", code: 1) }
        // Minimal PCM16 WAV reader (fixture is mono 16 kHz).
        let sr = Int(data.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
        let bits = Int(data.subdata(in: 34..<36).withUnsafeBytes { $0.load(as: UInt16.self).littleEndian })
        guard bits == 16 else { throw NSError(domain: "wav", code: 2) }
        // Find data chunk
        var offset = 12
        var payload = Data()
        while offset + 8 <= data.count {
            let id = String(data: data.subdata(in: offset..<(offset + 4)), encoding: .ascii) ?? ""
            let size = Int(data.subdata(in: (offset + 4)..<(offset + 8)).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
            let start = offset + 8
            let end = min(start + size, data.count)
            if id == "data" {
                payload = data.subdata(in: start..<end)
                break
            }
            offset = start + size + (size % 2)
        }
        var samples: [Float] = []
        samples.reserveCapacity(payload.count / 2)
        payload.withUnsafeBytes { raw in
            let ints = raw.bindMemory(to: Int16.self)
            for v in ints {
                samples.append(Float(Int16(littleEndian: v)) / 32768.0)
            }
        }
        return (samples, sr)
    }
}
