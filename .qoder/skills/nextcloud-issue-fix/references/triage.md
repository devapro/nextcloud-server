# Issue triage rubric

Goal: a short ranked list of upstream `nextcloud/server` issues that (a) are worth fixing,
(b) fit one small PR, and (c) can be reproduced and verified on the local Docker harness.

## Queries

`origin` is the fork `devapro/nextcloud-server`; queries always target the upstream repo
explicitly. Labels verified live (2026-09): **`bug` (~1100 open), `enhancement`,
`good first issue`** — there is no `type:bug`. Re-verify against
`gh api repos/nextcloud/server/labels --paginate --jq '.[].name'` if a query comes back empty.

```bash
# primary pool: open bugs (gh 2.4 has no `gh search` — use the api everywhere)
gh api "search/issues?q=repo:nextcloud/server+is:issue+is:open+label:bug&sort=updated&per_page=40" \
  --jq '.items[] | {number,title,labels:[.labels[].name],updated:.updated_at,url}'
# opportunistic pools (only with per-item human sign-off, see SKILL.md)
gh api "search/issues?q=repo:nextcloud/server+is:issue+is:open+label:%22good+first+issue%22&per_page=25" --jq '.items[] | {number,title,labels:[.labels[].name],url}'
gh api "search/issues?q=repo:nextcloud/server+is:issue+is:open+label:enhancement&sort=updated&per_page=25" --jq '.items[] | {number,title,labels:[.labels[].name],url}'
```

Pull full bodies for the survivors: `gh api repos/nextcloud/server/issues/<n>` — save to
`.qoder/issue-fix/<n>/issue.json`.

## Hard exclusions (drop immediately)

- **Security reports** or anything hinting at a vulnerability → stop; goes to
  [HackerOne](https://hackerone.com/nextcloud) via a human, never a public PR.
- Bug is in a non-bundled app or a separate frontend repo (Talk, Forms, Desktop, mobile) —
  this repo only ships bundled apps.
- Root cause is inside `3rdparty/` (git submodule `nextcloud/3rdparty`) — cannot be fixed here.
- Needs external services to reproduce: LDAP/AD, S3-compatible object store, SMTP/IMAP,
  onlyoffice/collabora, SSO idPs, WebTalk signaling, specific client versions.
- `needs info` still pending, or an active design/maintainer debate in the thread, or it already
  has an open linked PR (check `gh api repos/nextcloud/server/issues/<n>/timeline` for
  `cross-referenced` PRs).
- Environment-specific reports (reverse proxy, nginx, browser extension) with no server-side path.
- Anything requiring a schema migration + data backfill for corrupted prod data — verification
  on a fresh SQLite instance would not exercise the real failure.

## Scoring (0-10, sum of)

| Criterion | Max | What to look for in the issue |
|---|---|---|
| Repro clarity | 3 | Concrete steps + expected/actual, version, screenshots or OCC output |
| Fix locality | 3 | Stack trace or logs name a file; single app or `lib/` subsystem; diff plausibly < ~150 lines |
| Web-testability | 2 | The broken surface is reachable in browser (settings page, files UI, sharing dialog, login, dashboard) or via OCS/WebDAV call the harness can make |
| Still present | 2 | Read the implicated code at current `develop`; the bug must still be derivable from the source. Grep for the symptom; check recent commits (`git log --since --oneline -- <path>`) |

Score < 6 → not shortlisted. `good first issue` / enhancement candidates: cap contribution so
they rarely beat a clear `bug` — that's intended.

## Tie-breakers

- Prefer issues linked to a version tag ≥ the fork base (currently `develop` = 35).
- Prefer regressions reported with a "worked in <previous version>" line.
- Among equals, prefer UI bugs (better screenshot evidence) over API-behavior bugs.

## Shortlist output (`.qoder/issue-fix/triage.md`)

For each candidate, one block: issue #, title, score + per-criterion notes, implicated
module path(s), proposed reproduction test (which Playwright spec / occ command fails on a
clean tree), and the risk that sinks it ("fix may turn out to be in 3rdparty/").
