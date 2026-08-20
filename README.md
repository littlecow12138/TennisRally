# TennisRally

iOS (iPhone) app for offline tennis rally splitting.

## Scope

1. Library / Import — Photos or Files
2. Offline processing — onset clustering + bounce/short filters (LCOW-4 frozen pipeline)
3. Rally timeline — index, start/end, scrub/correct entry points
4. Correction editor / review export (UI from LCOW-7 shell)

Brand assets: logo mark 01, app icon 02, wordmark lockup 03.

Locales: English + 简体中文 (`en`, `zh-Hans`).

## Offline split pipeline

Port of `_draft/segment_img4257_batch.py`:

1. Extract mono 16 kHz PCM from the imported video (AVFoundation)
2. Spectral-flux onset peaks → cluster by gap
3. Reject bounce / micro / metronomic false positives
4. Present remaining intervals as the rally list

Reference notes: `_draft/PIPELINE_STATUS.md`.

## Build

```bash
xcodegen generate
xcodebuild -scheme TennisRally -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Open `TennisRally.xcodeproj` in Xcode if you prefer the GUI.

## Smoke path

1. Library → **Import from Photos** or **Import from Files**
2. Wait for offline processing (Process tab)
3. Rallies tab shows detected intervals (`start`–`end`)
4. Failures surface alerts (decode / no audio / no rallies) without crashing

Suggested short clip: `IMG_4257 2.MOV`.
