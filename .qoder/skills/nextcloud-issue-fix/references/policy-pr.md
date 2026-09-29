# Commit, PR and policy gates

Full policy: https://github.com/nextcloud/.github/blob/master/AI_POLICY.md and
`.github/CONTRIBUTING.md`. PRs here target the **fork** (`devapro/nextcloud-server`, base
`develop`). Upstream contribution rules still apply to what a PR would look like, because the
fork's purpose is staging real contributions.

## Branch & commit

- Branch from current `origin/develop`: `fix/issue-<n>-<short-slug>`.
- Conventional Commits, scope = app or component (`fix(files_sharing): …`, `fix(lib): …`) —
  enforced upstream by `block-unconventional-commits.yml`. Types: feat fix refactor test docs
  chore perf build ci.
- Commit body: what/why, `Fixes #<n>` referencing the upstream issue.
- Every AI-assisted commit carries the trailer:
  `Assisted-by: Qoder CLI:<MODEL_VERSION>` — ask the human for the exact model string; never guess it.
- **Never** add `Signed-off-by` — only the human contributor certifies the DCO.
- One PR = one issue = one purpose. If the diff grows across subsystems, stop and propose a
  split (or a pre-ticket) instead of pushing on.

## What must never be hand-edited

`dist/`, `apps/*/l10n/`, `openapi*.json`/`openapi.json`, `3rdparty/`, `lib/composer/` (except
regenerated classmaps), `apps/*/composer/composer/`. Regenerate via:
`npm run build` (+ `build/npm-post-build.sh` runs sass), `bash build/autoloaderchecker.sh`,
`bash build/openapi-checker.sh`, `composer run psalm -- --update-baseline` — and commit the
result. CI diffs these exactly.

## Local-only artifacts

`.qoder/` lives at repo root and is **never committed**: it appears as an "additional file" in
`build/files-checker.php` runs locally — that entry is expected and excluded from any
"checker failed" alarm. Keep scratch/evidence under `.qoder/issue-fix/<n>/` only.

## Human approval gates (blocking)

1. **Shortlist**: human picks the issue before any code is written.
2. **Push**: `git push` to the fork requires a new explicit confirmation in the conversation —
   showing branch, commit list and diffstat first. One approval covers one push, ever.
3. **PR creation**: separate confirmation after the push; the agent shows the final PR title,
   body and target (`devapro/nextcloud-server`, base `develop`) before running
   `gh pr create --repo devapro/nextcloud-server --head <branch> --base develop`.
4. Never: comment on/close upstream issues, open upstream PRs, file security reports, or
   auto-resolve a `good first issue` end-to-end without the human at each gate.

If any planned step conflicts with the AI policy, say so explicitly, name the rule, and stop.

## PR body template

```markdown
## Summary
- <one-line what/why, module scope>

Fixes #<upstream issue number>

## Test plan
- [ ] Failing repro: `tests/playwright/e2e/<area>/<spec>.spec.ts` on develop — symptom shown
- [ ] Same spec green on this branch
- [ ] Full `<area>` Playwright suite green in Docker harness
- [ ] <unit/phpunit/cs/psalm commands actually run, with outcomes>

## Manual verification
Steps from the issue on <branch> in Docker (SQLite, v<version>), <before/after screenshots below>.

<details><summary>AI assistance disclosure</summary>

- Tool: Qoder CLI, model <MODEL_VERSION>
- AI-assisted code; human-reviewed. Regenerated artifacts included (dist/…, classmaps, openapi, psalm baselines as applicable).
</details>
```

Screenshots: attach from `.qoder/issue-fix/<n>/evidence/` via `gh` upload on create, or paste
paths into the body draft for the human to attach.

## Verification before offering the push gate

`git status --porcelain` clean of stray generated files; every touched surface re-checked with
its gate checker; result matrix complete (see verification.md). Nothing ships "untested" — if
the harness could not run, report exactly which cell of the matrix is unverified and let the
human decide.
