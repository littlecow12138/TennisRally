import AVFoundation
import Foundation

enum VideoAudioExtractorError: LocalizedError, Equatable {
    case cannotOpenAsset
    case noAudioTrack
    case readerFailed(String)
    case decodeFailed
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .cannotOpenAsset:
            return String(localized: "error.decode_failed")
        case .noAudioTrack:
            return String(localized: "error.no_audio")
        case .readerFailed:
            return String(localized: "error.decode_failed")
        case .decodeFailed:
            return String(localized: "error.decode_failed")
        case .emptyAudio:
            return String(localized: "error.no_audio")
        }
    }
}

enum VideoAudioExtractor {
    static let targetSampleRate = 16_000

    /// Extracts mono PCM float samples at 16 kHz from a local video URL.
    static func extractMono16k(from url: URL) async throws -> (samples: [Float], sampleRate: Int, duration: TimeInterval) {
        let asset = AVURLAsset(url: url)
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw VideoAudioExtractorError.cannotOpenAsset
        }
        guard let track = tracks.first else {
            throw VideoAudioExtractorError.noAudioTrack
        }

        let duration: TimeInterval
        do {
            let cm = try await asset.load(.duration)
            duration = cm.seconds.isFinite ? cm.seconds : 0
        } catch {
            duration = 0
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            throw VideoAudioExtractorError.cannotOpenAsset
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else {
            throw VideoAudioExtractorError.readerFailed("cannot add audio output")
        }
        reader.add(output)

        guard reader.startReading() else {
            throw VideoAudioExtractorError.readerFailed(reader.error?.localizedDescription ?? "startReading failed")
        }

        var samples: [Float] = []
        samples.reserveCapacity(Int(max(duration, 1) * Double(targetSampleRate)))

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            guard length > 0 else { continue }
            var data = Data(count: length)
            let copyStatus = data.withUnsafeMutableBytes { raw -> OSStatus in
                guard let base = raw.baseAddress else { return -1 }
                return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: base)
            }
            guard copyStatus == kCMBlockBufferNoErr else { continue }
            let floatCount = length / MemoryLayout<Float>.size
            data.withUnsafeBytes { raw in
                let buffer = raw.bindMemory(to: Float.self)
                samples.append(contentsOf: buffer.prefix(floatCount))
            }
        }

        if reader.status == .failed {
            throw VideoAudioExtractorError.decodeFailed
        }
        guard !samples.isEmpty else {
            throw VideoAudioExtractorError.emptyAudio
        }

        let resolvedDuration = duration > 0 ? duration : Double(samples.count) / Double(targetSampleRate)
        return (samples, targetSampleRate, resolvedDuration)
    }
}
