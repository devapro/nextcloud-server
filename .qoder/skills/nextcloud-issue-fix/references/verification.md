# Docker + Chrome verification

Two runners, used together:

- **Playwright harness** (`tests/playwright/start-nextcloud-server.js` + `@nextcloud/e2e-test-server`)
  — primary. A Nextcloud container with local code bind-mounted, SQLite, exposed on `localhost:8042`.
- **browser-use MCP** against the same running container — interactive walkthroughs and PR
  screenshots. A second full-stack option, `.devcontainer/docker-compose.yml` (Apache+PHP 8.4+
  postgres, whole repo mounted at `:80`), exists as fallback if the harness can't boot.

## Prerequisites

`bash .qoder/skills/nextcloud-issue-fix/scripts/envcheck.sh` — checks submodules, `lib/composer`,
`node_modules`, docker daemon, `gh` auth, port 8042. Bootstrap anything it flags:

```bash
git submodule update --init --depth 1        # 3rdparty
composer install
npm ci                                       # pulls @nextcloud/e2e-test-server
npx playwright install chromium              # or: npm run playwright:install
```

## The harness, facts

- Start: `NEXTCLOUD_PORT=8042 node tests/playwright/start-nextcloud-server.js` (background);
  ready marker on stdout: `Nextcloud container ready to run Playwright tests`. Playwright's
  `webServer` does this automatically and `reuseExistingServer: !CI` keeps it warm between runs.
- The base image comes from `@nextcloud/e2e-test-server` (`BRANCH` env selects its branch);
  local files **shadow** these paths inside the container — everything else is image-default:
  `3rdparty/ apps/ core/ dist/ lib/ ocs/ ocs-provider/ resources/ tests/` plus root
  `console.php cron.php index.php occ public.php remote.php status.php version.php`
  (whitelist in `getMounts()`, files exist-checked).
  Consequences: a fix in **any bundled app's PHP** is live immediately; a `dist/` JS change
  requires `npm run build` first; `config/`, `themes/`, `.htaccess` are **not** mounted —
  system config only via `occ` inside the container.
- Credentials: `admin`/`admin`; baseURL `http://localhost:8042/index.php/`
  (`playwright.config.ts:19`). OCS Basic auth `admin:admin` as in
  `tests/playwright/support/utils/users.ts:26`. App store disabled; `viewer` preinstalled;
  `password_policy` disabled; app-config cache off; cron ran once.
- Run occ / commands in the container: `docker ps` to find the container exposing 8042, then
  `docker exec <ctr> php occ …` (add `-u www-data` / `sudo -u www-data` on file-permission
  errors). Or use `runOcc` / `runExec` from `@nextcloud/e2e-test-server/docker` in a node script.
- Spec layout: `tests/playwright/e2e/<area>/*.spec.ts`, fixtures/helpers in
  `tests/playwright/support/` (`admin-session`, `random-user-session`, `login` from
  `@nextcloud/e2e-test-server/playwright`). Project `setup` (@setup, uninstalls the server)
  must never run alongside others.

## Reproduction gate (before any fix)

1. Clean tree (`git status --porcelain` empty of code changes; new spec may be untracked).
2. Write the failing evidence: a Playwright spec under the area dir reproducing the issue, or —
   if the bug is not UI-reachable — an equivalent failing PHPUnit/occ assertion.
3. `npm run playwright -- tests/playwright/e2e/<area>/<name>.spec.ts` → must **fail** with the
   issue's symptom. A pass here means the repro is wrong or the bug is gone; go back to triage.

## Full verification (after the fix)

- Targeted spec passes.
- Adjacent suite passes: run the whole `tests/playwright/e2e/<area>/` directory.
- If PHP touched: `composer test -- tests/lib/<…>` or app tests for the affected classes;
  plus the matching gate checker (`composer cs:check` / `psalm` / `build/autoloaderchecker.sh`
  / `openapi-checker.sh` — whichever applies to what was edited).
- Regenerated artifacts are present in the diff (dist/, classmaps, openapi, psalm baselines) —
  see SKILL.md non-negotiables.

## browser-use pass + evidence

With the harness container still up: `navigate_page http://localhost:8042`, log in as
admin/admin, walk the exact steps from the issue; `take_screenshot` before/after states.
Evidence goes to `.qoder/issue-fix/<n>/evidence/` — these files attach to the PR body; the
browser session must never be pointed at any real/external Nextcloud.

## Result matrix (written to `.qoder/issue-fix/<n>/verification.md`)

| Scenario | Base (develop) | Branch (fix) |
|---|---|---|
| Failing repro spec | ✗ expected | ✓ required |
| Adjacent suite | ✓ | ✓ required |
| Manual browser steps | symptom shown (screenshot) | fixed (screenshot) |

Any required cell unverified → not shipped.
