# LCOW-19 Model download failure / stuck-at-0% — design spec

Status: awaiting human acceptance. Do **not** start test cases or engineering until accepted.

Extends LCOW-13 Vision model detail (empty / downloading / ready). This gate only covers **progress honesty**, **stall**, **failure**, and **retry**.

## Design read

iOS product UX for TennisRally: when a ~2.1 GB on-device vision model download sits at 0% then silently ends, users need clear connecting → stalled → failed → retry states in Hard Court language (dark-first). EN + 简体中文.

## Comps (source of truth)

| # | File | State |
|---|------|--------|
| 01 | `01-connecting-0.png` | Just started: 0% + “Connecting…” (not a failure) |
| 02 | `02-stalled-0.png` | No byte progress past threshold: stalled warning + Retry |
| 03 | `03-failed-retry.png` | Terminal failure: error panel + primary Retry |
| 04 | `04-settings-failed.png` | Settings AI row reflects Failed |
| 05 | `05-failed-zh.png` | Same failed detail in 简体中文 |

These five files are the acceptance set.

## Problem this gate solves

Today (and in LCOW-13 happy path) users see a progress bar at **0%**, wait a long time, then the download **ends with no clear error**. `.failed` currently collapses to the same UI as “not downloaded.”

## State machine (UI)

```text
Idle (Not on device)
  └─ Tap Download
       └─ Connecting (0%, indeterminate pulse, “Connecting…”)
            ├─ Bytes move → Downloading (LCOW-13 progress + Cancel)
            ├─ No progress ≥ stall threshold → Stalled (warning + Retry + Cancel)
            └─ Hard error / timeout end → Failed (error + Retry)
                 └─ Retry → back to Connecting
```

Cancel from Connecting / Stalled / Downloading returns to Idle (Not on device). No partial “ready.”

## Thresholds (behavior for engineering — design intent)

| Signal | Intent |
|--------|--------|
| Connecting | Show immediately on tap; copy says connecting, not “Downloading · 0%” alone |
| Stall threshold | ~20–30s with **zero byte progress** → Stalled (do not wait minutes) |
| Failed | Network error, HTTP failure, disk full, cancelled-by-system, or stall ignored then ended |

Exact timer is an engineering choice within the range; UX must not look “healthy” while stuck.

## Vision model detail — UI per state

### 1. Connecting (0%, healthy)

- Keep model card + facts from LCOW-13
- Progress: thin lime track; fill may stay empty or show soft indeterminate shimmer
- Primary line: `Connecting…` / `正在连接…`
- Secondary: `0% · 0 KB / ~2.1 GB` (or equivalent)
- Action: **Cancel** (danger text), same as downloading
- Do **not** show error styling yet

### 2. Stalled (0%, unhealthy)

- Progress bar remains visible but muted
- Inline status chip / banner (not a modal):
  - Title: `Download stalled` / `下载停滞`
  - Body: `No data received. Check Wi-Fi and try again.` / `未收到数据。请检查 Wi-Fi 后重试。`
- Primary CTA: lime **Retry** / **重试**
- Secondary: **Cancel** / **取消**
- Model card caption: `Stalled · 0%` / `已停滞 · 0%`

### 3. Failed (terminal)

- Distinct from Idle — do not reuse plain “Download model” only
- Error panel on surface:
  - Icon: SF-style warning / xmark in danger `#E8664D`
  - Title: `Download failed` / `下载失败`
  - Body: short human reason (e.g. network / storage). Prefer mapped copy over raw `localizedDescription` when possible
- Primary: lime **Retry download** / **重新下载**
- Optional muted hint: Wi-Fi recommended / storage needed (reuse facts)
- Cellular warning stays if on expensive network (LCOW-13)

### 4. Settings row (AI Assist → Vision model)

| Status | Subtitle EN | Subtitle ZH |
|--------|-------------|-------------|
| Connecting / Downloading | `Downloading · N%` | `下载中 · N%` |
| Stalled | `Stalled · 0%` | `已停滞 · 0%` |
| Failed | `Failed · tap to retry` | `失败 · 点按重试` |
| Ready / Idle | unchanged from LCOW-13 | unchanged |

Failed / Stalled may use danger or muted+danger accent on the subtitle only — keep row structure identical to LCOW-13.

## Copy table (ship EN + ZH)

| Key intent | EN | 简体中文 |
|------------|----|----------|
| Connecting | Connecting… | 正在连接… |
| Stalled title | Download stalled | 下载停滞 |
| Stalled body | No data received. Check Wi-Fi and try again. | 未收到数据。请检查 Wi-Fi 后重试。 |
| Failed title | Download failed | 下载失败 |
| Failed body (generic) | Couldn’t finish the download. Check your connection and free space, then retry. | 无法完成下载。请检查网络与可用空间后重试。 |
| Retry | Retry | 重试 |
| Retry download | Retry download | 重新下载 |
| Settings stalled | Stalled · 0% | 已停滞 · 0% |
| Settings failed | Failed · tap to retry | 失败 · 点按重试 |

## Tokens

Reuse Hard Court (LCOW-9 / LCOW-13):

| Token | Dark |
|-------|------|
| bg | `#0C1612` |
| surface | `#15241C` |
| accent | `#C8E83A` |
| text | `#F4F6F3` |
| muted | `#8A9A90` |
| danger | `#E8664D` |

Court chalk-line atmosphere. SF system fonts. Surface radius 14 continuous. Primary button: accent fill, black label.

## Out of scope for this gate

- Root-cause fix of the download pipeline (engineering after acceptance)
- Changing model file / source URL
- AI Assist inference / Rallies flows (LCOW-13)
- Light-theme comps (follow LCOW-9 light tokens when theming)
- Toast-only error (must be on-screen persistent state)

## Human acceptance checklist

- [ ] Connecting at 0% is visually distinct from Stalled / Failed
- [ ] Stalled appears after no progress, with clear Retry + Cancel
- [ ] Failed shows title + reason + primary Retry (not silent return to Idle)
- [ ] Settings row can show Stalled / Failed without layout change
- [ ] EN and ZH share one structure (comp 05)
- [ ] Matches Hard Court / LCOW-13 model detail chrome
- [ ] Ready for test cases & engineering **only after** this checklist is accepted
