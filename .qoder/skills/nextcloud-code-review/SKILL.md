---
name: nextcloud-code-review
description: Advisory AI code review of a Nextcloud server pull request (this repo or upstream nextcloud/server) or of the local working diff, scored against the ruleset in .github/AI_REVIEW.md. Use when the user asks to review a PR, a diff, or "потестируй ревью". Never posts anything to GitHub.
---

# Nextcloud code review

Review a pull request or local diff against the canonical ruleset and produce a structured
report on disk. **Never** create/post PR reviews, comments, labels or issue reports — a
human publishes the output.

## Inputs

`$ARGUMENTS` may be:

- a PR number (`64735`) → review `nextcloud/server#64735` (or the PR number against
  `github.repository` of the current remote if the user says "our repo");
- a PR URL (`https://github.com/owner/repo/pull/123`) → review that PR;
- `local` (or empty) → review the uncommitted working tree (`git diff HEAD` + untracked).

## Procedure

1. **Ruleset.** Read `.github/AI_REVIEW.md` in full — it defines rule IDs, severities and
   the mandatory report output format. Everything below cites it.
2. **Fetch evidence** into a scratch dir under `.qoder/reviews/pr-<number>/`:
   - `gh api repos/<owner>/<repo>/pulls/<n>` (title, author, base, head sha, `changed_files`),
   - `gh api repos/<owner>/<repo>/pulls/<n>/files --paginate` (per-file patches; `patch` may
     be null for huge/binary files — mark those as not covered),
   - `gh pr diff <n> --repo <owner>/<repo>` as fallback when the files API truncates.
   For `local`: `git status --porcelain`, `git diff HEAD`.
3. **Bucket the files** and dispatch sub-agents in parallel (one Agent call per bucket,
   only for non-empty buckets):
   - `php-reviewer` — `lib/**/*.php`, `apps/*/lib/**/*.php`, `core/lib`, `config.sample.php`,
     migrations, `appinfo/*`, PHP tests under `tests/` and `apps/*/tests/`;
   - `frontend-reviewer` — `apps/*/src/**`, `core/src/**`, `dist/**`, `package.json`,
     `build/frontend*/**`, `*.vue`, `*.ts`, `*.js`, styles;
   - `policy-checker` — runs on every review: repo-policy artifacts (regenerated
     autoloaders/openapi/dist/psalm baselines), SPDX headers, root-file whitelist, commit
     conventions and AI trailers.
   Each sub-agent gets: the ruleset path, the PR metadata, and its slice of the diff. If a
   custom agent type is not callable (`Unknown agent type`), dispatch `general-purpose`
   instead and paste the corresponding file from `.qoder/agents/` as the first block of
   the brief.
4. **Merge findings**: deduplicate identical file:line+rule hits, sort blocker → major →
   minor → question, cap at 15 and record how many were dropped.
5. **Write the report** in the exact "Output format" of the ruleset to
   `.qoder/reviews/pr-<number>-<UTC timestamp>.md` (for `local`,
   `.qoder/reviews/local-<timestamp>.md`), then print the report to the user with the file
   path. Findings stay advisory: do not rephrase a question as a demand, do not propose to
   post anything.

## Verification discipline

- A sub-agent claim that "function X / file Y does not exist" must be re-checked with
  Grep/Glob in the main agent before it appears in the report (sub-agents hallucinate
  absence as easily as presence).
- Do not report anything CI checkers already enforce mechanically as a finding; put it in
  Notes only if a required regeneration appears to be missing from the PR itself.

## Testing the CI pipeline locally

The GitHub Actions job uses the same ruleset through a different runner:

```bash
DRY_RUN=1 REPO=nextcloud/server PR_NUMBER=<n> ENGINE=claude \
  bash .github/scripts/ai-review.sh
```

This exercises the workflow prompt end-to-end without posting (requires `gh`, `claude`
and an API key). Use it to validate ruleset or prompt changes before committing.
