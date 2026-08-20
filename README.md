# TennisRally

iOS (iPhone) app for offline tennis rally splitting.

## Scope (LCOW-7 UI shell)

Implements the accepted design gate screens:

1. Library / Import
2. Offline processing
3. Rally timeline
4. Correction editor (trim / merge / split / reset)
5. Review + export clip

Brand assets: logo mark 01, app icon 02, wordmark lockup 03.

Locales: English + 简体中文 (`en`, `zh-Hans`).

## Design tokens

- bg `#0C1612`
- surface `#15241C`
- accent `#C8E83A`
- chalk `#E8E4DC`
- text `#F4F6F3`
- muted `#8A9A90`

## Build

```bash
xcodegen generate
xcodebuild -scheme TennisRally -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Open `TennisRally.xcodeproj` in Xcode if you prefer the GUI.

## Notes

- v1 UI shell uses demo session data; real Photos import + ML boundary detection land with the PoC/MVP follow-ups.
- Processing → Rallies flow is wired end-to-end in the session store for reviewable navigation.

## Contributing

PRs must link a Multica issue (`LCOW-N` in the title + `Closes LCOW-N` in the body). See [CONTRIBUTING.md](CONTRIBUTING.md).
