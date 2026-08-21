# Contributing

## Multica issue linking (required)

Standing rule: **every code PR must link its Multica issue.**

| Where | Required form |
| --- | --- |
| PR **title** | `LCOW-N: …` (workspace issue key prefix) |
| PR **body** | `Closes LCOW-N` (closing keyword immediately before the key) |
| Branch (recommended) | include `lcow-n` / `LCOW-N` |

If the Multica issue shows **no** linked PR after open/update, check GitHub→Multica integration (webhooks) — title/body alone cannot invent a link when delivery is missing.

Do **not** open or merge a PR that omits the key.

GitHub fills `.github/pull_request_template.md` when you open a PR; keep the `Closes LCOW-N` line.
