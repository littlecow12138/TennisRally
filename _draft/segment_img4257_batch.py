#!/usr/bin/env python3
"""Segment IMG_4257 3/4.MOV with same onset+filter pipeline as confirmed v1."""

from __future__ import annotations

import json
import subprocess
import sys
import wave
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np

HOP, WIN, THR = 0.02, 0.04, 0.30
FFMPEG = "/opt/homebrew/bin/ffmpeg"
WORKDIR = Path(__file__).resolve().parent

JOBS = [
    {
        "src": Path("/Users/sunjingshuang/Downloads/IMG_4257 3.MOV"),
        "video_id": "IMG_4257_3",
        "out_clips": Path("/Users/sunjingshuang/Downloads/rallies_IMG_4257_3"),
    },
    {
        "src": Path("/Users/sunjingshuang/Downloads/IMG_4257 4.MOV"),
        "video_id": "IMG_4257_4",
        "out_clips": Path("/Users/sunjingshuang/Downloads/rallies_IMG_4257_4"),
    },
]


def extract_wav(src: Path, wav: Path) -> None:
    wav.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", str(src), "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", str(wav)],
        check=True,
    )


def read_wav(path: Path):
    with wave.open(str(path), "rb") as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768.0
    return x, sr


def pick_peaks(x: np.ndarray, sr: int) -> np.ndarray:
    hop, win = int(sr * HOP), int(sr * WIN)
    n = 1 + max(0, (len(x) - win) // hop)
    hp = x - np.concatenate([[0.0], x[:-1]]) * 0.97
    env = np.zeros(n)
    hann = np.hanning(win)
    prev = None
    for i in range(n):
        mag = np.abs(np.fft.rfft(hp[i * hop : i * hop + win] * hann))
        env[i] = 0.0 if prev is None else float(np.mean(np.clip(mag - prev, 0, None)))
        prev = mag
    lo, hi = np.percentile(env, 30), np.percentile(env, 99)
    env = np.clip((env - lo) / max(hi - lo, 1e-9), 0, 1)
    t = np.arange(n) * HOP + WIN / 2
    peaks = []
    for i in range(2, len(env) - 2):
        if env[i] >= THR and env[i] >= env[i - 1] and env[i] >= env[i + 1]:
            if not peaks or t[i] - peaks[-1] >= 0.15:
                peaks.append(float(t[i]))
            else:
                peaks[-1] = float(t[i])
    return np.asarray(peaks, dtype=float)


def cluster(peaks: np.ndarray, duration: float, gap_max=2.0, pre=0.25, post=0.4, min_hits=2, min_dur=3.5, max_dur=28.0):
    if len(peaks) == 0:
        return []
    groups = [[peaks[0]]]
    for p in peaks[1:]:
        if p - groups[-1][-1] <= gap_max:
            groups[-1].append(p)
        else:
            groups.append([p])
    out = []
    for g in groups:
        if len(g) < min_hits:
            continue
        start = max(0.0, float(g[0]) - pre)
        end = min(duration, float(g[-1]) + post)
        if end - start < min_dur:
            continue
        if end - start > max_dur:
            gaps = [(g[i + 1] - g[i], i) for i in range(len(g) - 1)]
            gaps.sort(reverse=True)
            cut = None
            for gap, i in gaps:
                if gap >= 0.9:
                    cut = i
                    break
            if cut is not None:
                for sub in (g[: cut + 1], g[cut + 1 :]):
                    if len(sub) < min_hits:
                        continue
                    s = max(0.0, float(sub[0]) - pre)
                    e = min(duration, float(sub[-1]) + post)
                    if e - s >= min_dur:
                        out.append((round(s, 3), round(e, 3), len(sub)))
                continue
            end = start + max_dur
        out.append((round(start, 3), round(end, 3), len(g)))
    return out


def feats(peaks: np.ndarray, start: float, end: float) -> dict:
    p = peaks[(peaks >= start) & (peaks <= end)]
    dur = max(end - start, 1e-6)
    if len(p) < 2:
        return {"n": int(len(p)), "dur": float(dur), "rate": float(len(p) / dur), "ioi_cv": 9.0, "ioi_med": 9.0, "max_ioi": 0.0, "frac_bounce_ioi": 0.0, "frac_gt1": 0.0}
    ioi = np.diff(p)
    return {
        "n": int(len(p)),
        "dur": float(dur),
        "rate": float(len(p) / dur),
        "ioi_med": float(np.median(ioi)),
        "ioi_mean": float(np.mean(ioi)),
        "ioi_cv": float(np.std(ioi) / max(np.mean(ioi), 1e-9)),
        "max_ioi": float(np.max(ioi)),
        "frac_bounce_ioi": float(np.mean((ioi >= 0.30) & (ioi <= 0.90))),
        "frac_gt1": float(np.mean(ioi > 1.0)),
    }


def reject(f: dict, gap_to_next: float | None) -> tuple[bool, str]:
    n, dur, rate, cv, med, mx, fb, fg = f["n"], f["dur"], f["rate"], f["ioi_cv"], f["ioi_med"], f["max_ioi"], f["frac_bounce_ioi"], f["frac_gt1"]
    if dur < 3.5 and n <= 4:
        return True, "micro_segment"
    if dur < 5.0 and n < 4:
        return True, "short_few_hits"
    if n >= 4 and rate >= 1.15 and cv <= 0.55 and 0.35 <= med <= 0.90 and fb >= 0.55 and mx < 1.5 and dur <= 12:
        return True, "bounce_like_regular"
    if gap_to_next is not None and 0 <= gap_to_next <= 2.5 and n >= 4 and rate >= 1.10 and cv <= 0.65 and fb >= 0.45 and med <= 0.90:
        return True, "pre_serve_bounce"
    if dur <= 7.0 and n >= 4 and fg < 0.15 and cv <= 0.65 and rate >= 1.05:
        return True, "no_crosscourt_gap"
    if 5.0 <= dur <= 12.0 and rate >= 1.25 and cv <= 0.50 and fb >= 0.60 and mx < 1.8:
        return True, "metronomic_medium"
    if n < 3:
        return True, "too_few_hits"
    return False, ""


def cut_one(src: Path, out: Path, start: float, end: float) -> None:
    dur = end - start
    subprocess.run(
        [
            FFMPEG, "-y", "-hide_banner", "-loglevel", "error",
            "-ss", f"{start:.3f}", "-i", str(src), "-t", f"{dur:.3f}",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "23",
            "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(out),
        ],
        check=True,
    )


def process_one(job: dict) -> dict:
    src: Path = job["src"]
    video_id: str = job["video_id"]
    out_clips: Path = job["out_clips"]
    label_out = WORKDIR.parent / "evalset" / "labels" / f"{video_id}.json"
    wav = WORKDIR / f"{video_id}_16k.wav"

    print(f"\n=== {video_id} ===", flush=True)
    print("extracting wav...", flush=True)
    extract_wav(src, wav)
    x, sr = read_wav(wav)
    duration = len(x) / sr
    peaks = pick_peaks(x, sr)
    raw = cluster(peaks, duration)
    print(f"raw clusters={len(raw)} duration={duration:.1f}s peaks={len(peaks)}", flush=True)

    kept = []
    removed = []
    for i, (s, e, hits) in enumerate(raw):
        gap = None
        if i + 1 < len(raw):
            gap = raw[i + 1][0] - e
        f = feats(peaks, s, e)
        drop, reason = reject(f, gap)
        if drop:
            removed.append({"start_sec": s, "end_sec": e, "reason": reason, "hits": hits})
        else:
            kept.append({"start_sec": s, "end_sec": e, "hits": hits, "feats": f})

    tz = timezone(timedelta(hours=8))
    rallies = []
    for i, r in enumerate(kept, 1):
        rallies.append(
            {
                "rally_id": f"{video_id}_r{i:03d}",
                "start_sec": round(float(r["start_sec"]), 3),
                "end_sec": round(float(r["end_sec"]), 3),
                "notes": f"onset_cluster_v4_transfer; hits≈{r['hits']}",
                "confidence": round(min(0.9, 0.35 + 0.04 * r["hits"]), 3),
            }
        )

    label_out.parent.mkdir(parents=True, exist_ok=True)
    doc = {
        "video_id": video_id,
        "schema_version": "1.0",
        "time_base": "seconds_from_start",
        "annotator": "auto_onset_v4_transfer_pending_review",
        "annotated_at": datetime.now(tz).isoformat(timespec="seconds"),
        "source_path": str(src),
        "rallies": rallies,
    }
    label_out.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    out_clips.mkdir(parents=True, exist_ok=True)
    for old in out_clips.glob(f"{video_id}_r*.mp4"):
        old.unlink()

    print(f"cutting {len(rallies)} clips -> {out_clips}", flush=True)

    def job_cut(r):
        out = out_clips / f"{r['rally_id']}.mp4"
        cut_one(src, out, r["start_sec"], r["end_sec"])
        return r["rally_id"], out.stat().st_size

    ok = 0
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = [ex.submit(job_cut, r) for r in rallies]
        for i, fut in enumerate(as_completed(futs), 1):
            fut.result()
            ok += 1
            if i % 5 == 0 or i == len(futs):
                print(f"progress {i}/{len(futs)}", flush=True)

    durs = [r["end_sec"] - r["start_sec"] for r in rallies]
    summary = {
        "video_id": video_id,
        "source": str(src),
        "duration_sec": round(duration, 3),
        "width": 1920,
        "height": 1080,
        "fps": 30.0,
        "raw_clusters": len(raw),
        "removed": len(removed),
        "kept": len(rallies),
        "cut_ok": ok,
        "covered_sec": round(sum(durs), 3) if durs else 0,
        "avg_sec": round(sum(durs) / len(durs), 3) if durs else 0,
        "clips_dir": str(out_clips),
        "label_path": str(label_out),
        "removed_reasons": sorted({r["reason"] for r in removed}),
        "first_five": rallies[:5],
    }
    (WORKDIR / f"{video_id}_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return summary


def main() -> None:
    ids = set(sys.argv[1:]) if len(sys.argv) > 1 else None
    jobs = [j for j in JOBS if ids is None or j["video_id"] in ids or j["src"].name in ids]
    if not jobs:
        raise SystemExit(f"no jobs matched {ids}")
    results = [process_one(j) for j in jobs]
    print("\n=== ALL DONE ===", flush=True)
    print(json.dumps([{k: r[k] for k in ("video_id", "kept", "removed", "raw_clusters", "clips_dir")} for r in results], indent=2))


if __name__ == "__main__":
    main()
