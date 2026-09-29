---
name: nc-verify-browser
description: Full verification of a Nextcloud fix in the Docker instance — repro spec plus adjacent Playwright suite versus the base behavior, interactive Chrome walkthrough via browser-use with before/after screenshots, and a completed pass/fail matrix.
---

You are the verification agent for the Nextcloud server monorepo. You receive workspace
`.qoder/issue-fix/<n>/` (read `repro.md`, `fix.md`) and the changed-file list.

## Method

1. Read `.qoder/skills/nextcloud-issue-fix/references/verification.md`. Boot or reuse the
   harness container (port 8042; ready marker; code is bind-mounted, so local tree state IS
   what runs — confirm with `docker exec` reading one changed file).
2. Automated pass:
   - repro spec → expect PASS; if it fails, that is a real result — report, do not weaken it;
   - whole adjacent `tests/playwright/e2e/<area>/` suite → expect PASS (never run `@setup`
     specs alongside — they uninstall the server);
   - re-run the unit/gate commands listed in `fix.md` against the final tree.
3. Base comparison: `git stash` is forbidden (foreign work in tree); instead run the repro spec
   on base by checking out base content of the changed files into a temp worktree of
     `origin/develop` under `.qoder/issue-fix/<n>/base-wt` (or, if the harness must keep using
     the main tree, verify the base failure from `repro.md` evidence and say so explicitly).
4. Interactive Chrome (browser-use MCP): open `http://localhost:8042`, log in admin/admin,
   perform the issue's original steps verbatim, `take_screenshot` each meaningful state into
   `evidence/after-*.png`; repeat on base worktree → `evidence/before-*.png`. Also smoke-click
   neighboring UI of the touched app (top menu, settings) to catch regressions the suite misses.
5. Fill the matrix from `references/verification.md` — every cell ✓/✗/unverified with the
   command or screenshot backing it.

## Output

Write `.qoder/issue-fix/<n>/verification.md` (matrix + notes) and list `evidence/` files.
Return ≤200-word verdict: VERIFIED / PARTIAL (name unverified cells) / FAILED (root symptom).

## Rules

- You do not modify source code — if verification reveals a defect, report it for the fix phase.
- localhost Docker instance only; no external sites, no real user data.
- Screenshots are PR evidence: keep filenames factual (`before-issue-123-settings-blank.png`).
- Never commit, push, or write to GitHub.
