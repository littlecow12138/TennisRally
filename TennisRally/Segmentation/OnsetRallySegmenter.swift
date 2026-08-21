import Foundation
import Accelerate

/// Offline onset-peak → cluster → bounce/short/metronome filter pipeline.
/// Ported from `_draft/segment_img4257_batch.py` (LCOW-4 frozen snapshot).
struct OnsetRallySegmenter {
    struct Segment: Equatable {
        var start: TimeInterval
        var end: TimeInterval
        var hitCount: Int
    }

    struct Config: Equatable {
        var hopSec: Double = 0.02
        var winSec: Double = 0.04
        var peakThreshold: Double = 0.30
        var minPeakGapSec: Double = 0.15
        var gapMaxSec: Double = 2.0
        var prePadSec: Double = 0.25
        var postPadSec: Double = 0.4
        var minHits: Int = 2
        var minDurationSec: Double = 3.5
        var maxDurationSec: Double = 28.0
    }

    var config: Config = Config()

    func segment(samples: [Float], sampleRate: Int) -> [Segment] {
        guard sampleRate > 0, !samples.isEmpty else { return [] }
        let duration = Double(samples.count) / Double(sampleRate)
        let peaks = pickPeaks(samples: samples, sampleRate: sampleRate)
        let raw = cluster(peaks: peaks, duration: duration)
        return filter(raw: raw, peaks: peaks)
    }

    // MARK: - Onset peaks

    func pickPeaks(samples: [Float], sampleRate: Int) -> [Double] {
        let hop = max(1, Int(Double(sampleRate) * config.hopSec))
        let win = max(2, Int(Double(sampleRate) * config.winSec))
        guard samples.count >= win else { return [] }

        let nFrames = 1 + max(0, (samples.count - win) / hop)
        var highPassed = [Float](repeating: 0, count: samples.count)
        highPassed[0] = samples[0]
        if samples.count > 1 {
            for i in 1..<samples.count {
                highPassed[i] = samples[i] - samples[i - 1] * 0.97
            }
        }

        var hann = [Float](repeating: 0, count: win)
        vDSP_hann_window(&hann, vDSP_Length(win), Int32(vDSP_HANN_NORM))

        let fftLength = win
        guard let dft = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(fftLength), .FORWARD) else {
            return []
        }
        defer { vDSP_DFT_DestroySetup(dft) }

        let half = fftLength / 2
        var env = [Double](repeating: 0, count: nFrames)
        var prevMag: [Float]?
        var real = [Float](repeating: 0, count: half)
        var imag = [Float](repeating: 0, count: half)
        var frame = [Float](repeating: 0, count: fftLength)

        for i in 0..<nFrames {
            let start = i * hop
            for j in 0..<win {
                frame[j] = highPassed[start + j] * hann[j]
            }
            // Pack even/odd for zrop DFT input layout.
            var even = [Float](repeating: 0, count: half)
            var odd = [Float](repeating: 0, count: half)
            for j in 0..<half {
                even[j] = frame[j * 2]
                odd[j] = frame[j * 2 + 1]
            }
            vDSP_DFT_Execute(dft, even, odd, &real, &imag)

            var mag = [Float](repeating: 0, count: half)
            for j in 0..<half {
                mag[j] = sqrtf(real[j] * real[j] + imag[j] * imag[j])
            }

            if let prev = prevMag {
                // Match numpy: mean over bins of clip(mag - prev, 0)
                var sum: Float = 0
                for j in 0..<half {
                    sum += max(0, mag[j] - prev[j])
                }
                env[i] = Double(sum / Float(half))
            } else {
                env[i] = 0
            }
            prevMag = mag
        }

        let lo = percentile(env, 30)
        let hi = percentile(env, 99)
        let denom = max(hi - lo, 1e-9)
        for i in 0..<env.count {
            let v = (env[i] - lo) / denom
            env[i] = min(max(v, 0), 1)
        }

        var peaks: [Double] = []
        let thr = config.peakThreshold
        for i in 2..<(env.count - 2) {
            guard env[i] >= thr, env[i] >= env[i - 1], env[i] >= env[i + 1] else { continue }
            let t = Double(i) * config.hopSec + config.winSec / 2
            if peaks.isEmpty || t - peaks[peaks.count - 1] >= config.minPeakGapSec {
                peaks.append(t)
            } else {
                peaks[peaks.count - 1] = t
            }
        }
        return peaks
    }

    // MARK: - Cluster

    func cluster(peaks: [Double], duration: Double) -> [Segment] {
        guard !peaks.isEmpty else { return [] }
        var groups: [[Double]] = [[peaks[0]]]
        for p in peaks.dropFirst() {
            if p - groups[groups.count - 1].last! <= config.gapMaxSec {
                groups[groups.count - 1].append(p)
            } else {
                groups.append([p])
            }
        }

        var out: [Segment] = []
        for g in groups {
            guard g.count >= config.minHits else { continue }
            let start = max(0, g[0] - config.prePadSec)
            let end = min(duration, g[g.count - 1] + config.postPadSec)
            let dur = end - start
            if dur < config.minDurationSec { continue }

            if dur > config.maxDurationSec {
                var gaps: [(Double, Int)] = []
                for i in 0..<(g.count - 1) {
                    gaps.append((g[i + 1] - g[i], i))
                }
                gaps.sort { $0.0 > $1.0 }
                var cut: Int?
                for (gap, i) in gaps where gap >= 0.9 {
                    cut = i
                    break
                }
                if let cut {
                    let subs = [Array(g[0...cut]), Array(g[(cut + 1)...])]
                    for sub in subs {
                        guard sub.count >= config.minHits else { continue }
                        let s = max(0, sub[0] - config.prePadSec)
                        let e = min(duration, sub[sub.count - 1] + config.postPadSec)
                        if e - s >= config.minDurationSec {
                            out.append(Segment(start: round3(s), end: round3(e), hitCount: sub.count))
                        }
                    }
                    continue
                }
                let cappedEnd = start + config.maxDurationSec
                out.append(Segment(start: round3(start), end: round3(min(duration, cappedEnd)), hitCount: g.count))
                continue
            }
            out.append(Segment(start: round3(start), end: round3(end), hitCount: g.count))
        }
        return out
    }

    // MARK: - Filters

    func filter(raw: [Segment], peaks: [Double]) -> [Segment] {
        var kept: [Segment] = []
        for (i, seg) in raw.enumerated() {
            let gap: Double?
            if i + 1 < raw.count {
                gap = raw[i + 1].start - seg.end
            } else {
                gap = nil
            }
            let f = features(peaks: peaks, start: seg.start, end: seg.end)
            if reject(f, gapToNext: gap) != nil {
                continue
            }
            kept.append(seg)
        }
        return kept
    }

    struct Features {
        var n: Int
        var dur: Double
        var rate: Double
        var ioiCV: Double
        var ioiMed: Double
        var maxIOI: Double
        var fracBounceIOI: Double
        var fracGT1: Double
    }

    func features(peaks: [Double], start: Double, end: Double) -> Features {
        let p = peaks.filter { $0 >= start && $0 <= end }
        let dur = max(end - start, 1e-6)
        guard p.count >= 2 else {
            return Features(
                n: p.count,
                dur: dur,
                rate: Double(p.count) / dur,
                ioiCV: 9,
                ioiMed: 9,
                maxIOI: 0,
                fracBounceIOI: 0,
                fracGT1: 0
            )
        }
        var ioi: [Double] = []
        for i in 1..<p.count {
            ioi.append(p[i] - p[i - 1])
        }
        let mean = ioi.reduce(0, +) / Double(ioi.count)
        let variance = ioi.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(ioi.count)
        let std = sqrt(variance)
        let sorted = ioi.sorted()
        let med: Double
        if sorted.count % 2 == 0 {
            med = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        } else {
            med = sorted[sorted.count / 2]
        }
        let bounce = ioi.filter { $0 >= 0.30 && $0 <= 0.90 }.count
        let gt1 = ioi.filter { $0 > 1.0 }.count
        return Features(
            n: p.count,
            dur: dur,
            rate: Double(p.count) / dur,
            ioiCV: std / max(mean, 1e-9),
            ioiMed: med,
            maxIOI: ioi.max() ?? 0,
            fracBounceIOI: Double(bounce) / Double(ioi.count),
            fracGT1: Double(gt1) / Double(ioi.count)
        )
    }

    /// Returns rejection reason if the segment should be dropped.
    func reject(_ f: Features, gapToNext: Double?) -> String? {
        let n = f.n
        let dur = f.dur
        let rate = f.rate
        let cv = f.ioiCV
        let med = f.ioiMed
        let mx = f.maxIOI
        let fb = f.fracBounceIOI
        let fg = f.fracGT1

        if dur < 3.5 && n <= 4 { return "micro_segment" }
        if dur < 5.0 && n < 4 { return "short_few_hits" }
        if n >= 4 && rate >= 1.15 && cv <= 0.55 && med >= 0.35 && med <= 0.90 && fb >= 0.55 && mx < 1.5 && dur <= 12 {
            return "bounce_like_regular"
        }
        if let gap = gapToNext, gap >= 0, gap <= 2.5, n >= 4, rate >= 1.10, cv <= 0.65, fb >= 0.45, med <= 0.90 {
            return "pre_serve_bounce"
        }
        if dur <= 7.0 && n >= 4 && fg < 0.15 && cv <= 0.65 && rate >= 1.05 {
            return "no_crosscourt_gap"
        }
        if dur >= 5.0 && dur <= 12.0 && rate >= 1.25 && cv <= 0.50 && fb >= 0.60 && mx < 1.8 {
            return "metronomic_medium"
        }
        if n < 3 { return "too_few_hits" }
        return nil
    }

    // MARK: - Helpers

    private func round3(_ v: Double) -> Double {
        (v * 1000).rounded() / 1000
    }

    private func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let rank = min(max(p / 100.0, 0), 1) * Double(sorted.count - 1)
        let lo = Int(floor(rank))
        let hi = Int(ceil(rank))
        if lo == hi { return sorted[lo] }
        let w = rank - Double(lo)
        return sorted[lo] * (1 - w) + sorted[hi] * w
    }
}
