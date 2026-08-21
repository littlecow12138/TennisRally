# LCOW-13 AI Assist UX — design spec

Status: awaiting human acceptance. Do **not** start engineering until accepted.

## Design read

iOS product UX for TennisRally: on-device vision model download in Settings (MiniCPM-V-Apps–style model management), plus an **AI Assist** check on the Rallies list that judges whether each split clip looks like a real rally. Hard Court visual language, dark-first, EN + 简体中文.

## Comps (source of truth)

| # | File | State |
|---|------|--------|
| 01 | `01-settings-ai-model-empty.png` | Settings + AI Assist section, model not downloaded (EN) |
| 02 | `02-model-detail-not-downloaded.png` | Vision model detail, Download CTA |
| 03 | `03-model-downloading.png` | Download progress + Cancel |
| 04 | `04-model-ready.png` | Model ready + Remove |
| 05 | `05-rallies-ai-assist-entry.png` | Rallies list with AI Assist entry |
| 06 | `06-gate-model-missing.png` | Sheet when model missing |
| 07 | `07-ai-checking-progress.png` | On-device checking progress |
| 08 | `08-rallies-ai-results.png` | Results summary + per-rally status |
| 09 | `09-rally-ai-verdict.png` | Single-rally AI verdict → editor |
| 10 | `10-settings-ai-zh.png` | Settings + AI 辅助 (简体中文) |

These ten files are the acceptance set.

## User jobs

1. **Prepare model** — Settings → download vision model once (Wi-Fi preferred, on-device only).
2. **Validate splits** — After offline split, run AI Assist on the rally list.
3. **Act on verdicts** — Jump into Correction for “Needs review” / “Unclear” items.

## Flow

```text
Settings
  └─ AI Assist → Vision model
       ├─ Not downloaded → Download → progress → Ready
       └─ Ready → Remove (optional)

Rallies list
  └─ AI Assist
       ├─ No model → sheet → Go to Settings
       ├─ Has model → Checking splits… (Rally n of N)
       └─ Done → summary + per-row status
            └─ Open rally → AI verdict panel → Open editor
```

## Settings — AI Assist section

- New section below Language: **AI Assist** / **AI 辅助**
- Single navigation row:
  - Title: Vision model / 视觉模型
  - Subtitle status:
    - `Not downloaded · ~2.1 GB` / `未下载 · 约 2.1 GB`
    - `Downloading · 47%` / `下载中 · 47%`
    - `Ready · MiniCPM-V 4.0` / `已就绪 · MiniCPM-V 4.0`
  - Trailing chevron → model detail
- Footer caption: on-device privacy line (EN/ZH)

Keep existing Appearance + Language blocks unchanged (LCOW-9).

## Vision model detail (MiniCPM-inspired)

Inspired by MiniCPM-V-Apps model management, restyled to Hard Court:

| State | Primary UI | Secondary |
|-------|------------|-----------|
| Empty | Lime **Download model** | Wi-Fi / storage / local-only facts |
| Downloading | Progress bar + % + bytes | **Cancel** |
| Ready | Inline **Ready** + check | **Remove model** (danger) |

Notes for engineering (behavior only, not implementation):

- Remote download of GGUF (or equivalent) to app sandbox
- Idle timer disabled while downloading (MiniCPM pattern)
- Redownload / remove available when ready
- Cellular warning caption when not on Wi-Fi

Model name shown in comps: **MiniCPM-V 4.0** (placeholder; final model pick is an engineering decision after design acceptance).

## Rallies — AI Assist

### Entry

- On Rallies header actions, add **AI Assist** alongside Review all / Export
  - Comp 05 uses a primary lime CTA for discoverability; acceptable alternate is a third text link in the existing accent link row — pick one in implementation, keep hierarchy clear
- Hint copy: AI checks whether each split looks like a real rally

### Gate (no model)

- Bottom sheet: title, privacy body, **Go to Settings**, **Not now**
- Does not start inference

### Progress

- Full-screen calm progress: “Checking splits…” + “Rally n of N”
- Subline: On-device · model name
- **Stop** cancels remaining items; keep already-finished verdicts

### Results

Three verdicts only (inline in list rows, not stickers on video):

| Verdict | EN | ZH | Color |
|---------|----|----|-------|
| Pass | Looks good | 看起来正确 | accent `#C8E83A` |
| Fail | Needs review | 需复查 | danger `#E8664D` |
| Uncertain | Unclear | 不确定 | muted `#8A9A90` |

Summary strip above list, e.g. `AI checked · 9 look good · 2 need review · 1 unclear`.

### Single-rally verdict

- Panel under preview: status + short reason + optional confidence
- Primary: **Open editor** (existing Correction flow)
- Secondary: dismiss / keep verdict

AI never auto-trims. Human remains source of truth.

## Tokens

Reuse Hard Court (same as LCOW-9):

| Token | Dark |
|-------|------|
| bg | `#0C1612` |
| surface | `#15241C` |
| accent | `#C8E83A` |
| text | `#F4F6F3` |
| muted | `#8A9A90` |
| danger | `#E8664D` |

Court chalk-line atmosphere remains. SF system fonts. Surface radius 14 continuous. Primary button: accent fill, black label.

## Localization

Ship EN + 简体中文 for all new strings in this feature. Comp 10 locks ZH Settings structure.

## Out of scope for this gate

- Production model selection / quantization tradeoffs
- Batch auto-fix of boundaries
- Cloud inference
- New tab or account surfaces
- Light-theme comps for this feature (follow LCOW-9 light tokens when theming)

## Human acceptance checklist

- [ ] Settings AI Assist row is clear and on-brand with LCOW-9 Settings
- [ ] Model download states (empty / progress / ready / remove) are understandable
- [ ] Privacy “on-device only” is visible in Settings and the missing-model gate
- [ ] Rallies entry for AI Assist is discoverable without cluttering the list
- [ ] Missing-model gate routes to Settings instead of failing silently
- [ ] Progress + Stop behavior is clear
- [ ] Three verdicts (Looks good / Needs review / Unclear) are scannable in the list
- [ ] Verdict detail leads to Correction editor; AI does not auto-edit
- [ ] EN and ZH Settings share one structure
- [ ] Ready for engineering **only after** this checklist is accepted
