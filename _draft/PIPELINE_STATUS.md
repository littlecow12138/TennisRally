# Evalset snapshot (frozen)

Frozen at: 2026-08-20T20:25:42+08:00
Requested by member: proceed with current confirmed cuts; AI assist later.

## Layout

```text
evalset/
  manifest.json
  videos/<video_id>.mov   # symlinks to Downloads sources
  labels/<video_id>.json  # schema_version 1.0, member-confirmed GT
```

## Counts

| video_id | rallies | labeled duration (s) |
|----------|---------|----------------------|
| IMG_4257 | 22 | 210.08 |
| IMG_4257_2 | 7 | 86.13 |
| IMG_4257_3 | 20 | 202.44 |
| IMG_4257_4 | 19 | 200.93 |

**Total: 68 rallies / 4 videos**
Source duration: 3523.243s
Labeled rally duration: 699.58s

## Pipeline (reuse for next videos)

1. Audio onset peaks → cluster → bounce/short/metronome filters (`_draft/segment_img4257_batch.py`)
2. Export clips under `Downloads/rallies_<video_id>/`
3. Member prune non-rallies → renumber → confirm → promote annotator=`sunjs12138`

## Stage 1 gate vs current

| Gate | Need | Have |
|------|------|------|
| Videos | ≥5 | 4 |
| Rallies | ≥80 | 68 |
| Camera | tripod_side + include_in_go_gate | tripod_baseline / false |

Not marking Stage 1 done until gates are met or LCOW-2 is amended.
