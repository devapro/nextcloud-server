<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# AI Code Review Ruleset

Canonical review rules for automated code review of this repository, used by both the
CI review bot (`.github/workflows/ai-review.yml`) and the local Qoder skill
(`.qoder/skills/nextcloud-code-review`). Keep this file the single source of truth.

## Ground rules

1. Reviews are **advisory**. The bot never requests changes, blocks a merge, or acts on
   review findings. A human triages every report (see the project AI Contribution Policy).
2. Only comment on lines **in the diff** (or directly impacted by it). No drive-by remarks.
3. Do not flag anything a deterministic linter already enforces and CI runs on every push
   (php-cs-fixer, eslint/stylelint, psalm, the dist/autoload/openapi regeneration checks).
   CI will catch those; a human-wedge review adds noise.
4. Every finding must cite a **rule ID** from this file and a **file:line** in the diff.
5. Prefer one concrete, actionable sentence per finding, with a suggested fix where possible.
6. Verify before reporting: a claim that a symbol, file, or option exists must be checked
   against the code, not recalled. If you cannot verify, downgrade to a question.

## Severity

- **blocker** — exploitable security flaw, data loss, privilege escalation, silent breakage of existing behaviour.
- **major** — correctness bug, API-compatibility break, missing migration/regeneration that will fail at runtime or in CI for this change.
- **minor** — design smell, missing test for new logic, inadequate error handling at a system boundary.
- **question** — the reviewer cannot determine intent; ask instead of asserting.

## PHP rules

- **PHP-1 Strict typing**: every touched PHP file must keep `declare(strict_types=1);`;
  new interface/parent method implementations use `#[\Override]`.
- **PHP-2 Public API stability**: any change in `lib/public` (`OCP\`) or `lib/unstable`
  (`NCU\`) needs correct annotations: `@since` on every new class/method/const/enum case;
  `@experimental <version>` for NCU members; deprecations must name the replacement
  (`@deprecated <version> Use … instead`). Apps may only depend on `OCP\`; usage of
  `OC\` internals or `lib/private/legacy` `OC_*` from app code is a finding.
- **PHP-3 Routing & controllers**: new/changed controllers must carry auth attributes as
  PHP attributes (`#[NoAdminRequired]`, `#[PublicPage]`, `#[NoCSRFRequired]`, `#[CORS]`,
  `#[BruteForceProtection]`, `#[PasswordConfirmationRequired]`), extend `OCSController`
  for OCS routes, and return typed `DataResponse` shapes (`Http::STATUS_*` + payload type)
  so the OpenAPI extractor can read them. A controller change without regenerated OpenAPI
  specs in the same PR is a **major** finding.
- **PHP-4 Database**: only via `OCP\IDBConnection`; query builder preferred; every user
  value via `createNamedParameter()` with an explicit `PARAM_*` type — string
  interpolation/concatenation into SQL is a **blocker**. Schema changes ship as a
  migration in `apps/<app>/lib/Migration/` (`changeSchema()` + `postSchemaChange()`);
  `db_structure.xml`/`appinfo/database.xml` must never be reintroduced. New typed code
  should prefer `ITypedQueryBuilder`.
- **PHP-5 Config**: app values via `IAppConfig` (mind lazy-load flags), system config via
  `IConfig`, user config via `IUserConfig`; app-value methods on `IConfig` are deprecated.
- **PHP-6 Banned/required primitives**: `iconv` is banned; user-facing strings use the
  U+2026 ellipsis, never three ASCII dots; translatable strings wrapped in the l10n API.
- **PHP-7 App anatomy**: new services/listeners/capabilities/settings registered in
  `lib/AppInfo/Application.php` (`register()`); side effects in `boot()`; `info.xml`
  updated for dependencies/background jobs/navigations when relevant, including
  `<nextcloud min-version/max-version>` consistency with `version.php`.

## Security rules

- **SEC-1** Unvalidated request input reaching SQL, shell (`proc_open`, `exec`), filesystem
  paths (path traversal around `data/`), or redirects is a **blocker/major** as applicable.
- **SEC-2** Output of user-controlled data into HTML/JS without escaping — check Vue
  template contexts and `v-html` usage in particular — **blocker**.
- **SEC-3** Any privilege-relevant change (sharing permissions, group membership, auth,
  WebDAV backends, brute-force protection) must show the check happens server-side and
  covers the public-link and federated paths too.
- **SEC-4** Secrets/tokens must not be logged or placed in exceptions; crypto changes
  need explicit reasoning about IVs, key derivation, and backwards decryptability.

## Frontend rules

- **FE-1 Toolchain placement**: which tree bundles the app (`build/frontend` Vue3/Vite vs
  `build/frontend-legacy` Vue2/Webpack) is decided by the committed symlink farm and the
  hardcoded `modules` map. Adding a bundle requires *both* a symlink and a map entry; a PR
  touching `apps/*/src` without them is **major**.
- **FE-2 Naming convention**: PHP loads bundles via `Util::addScript('<app>', '<name>')`
  → `dist/<app>-<name>.mjs`; new script registrations must match an actually produced
  dist file.
- **FE-3 Dependencies**: shared npm deps live only in root `package.json`; no per-app
  `package.json`. New stores use Pinia (Vuex only survives in settings/user_status).
  Prefer `@nextcloud/*` helpers (`initial-state`, `l10n`, `axios`, `router`, `@nextcloud/vue`).
- **FE-4 Generated files**: `apps/*/l10n/*`, `dist/*`, compiled CSS are not hand-editable —
  flag manual edits **major**.
- **FE-5 Context coverage**: UI wiring changes should consider default authenticated view,
  public share pages, and embedded hosts (Smart Picker, reference widgets); a component
  event consumer left unhandled when the emitter changed is a finding.

## Testing rules

- **TEST-1** Changed or added logic must come with a new/updated unit test; refactoring to
  make a fix testable is encouraged. Missing test for non-trivial new logic is **minor**,
  for security-relevant logic **major**.
- **TEST-2** PHP tests touching the database need the `#[Group('DB')]` or `#[Group('SLOWDB')]`
  attribute (not `@group`); tests run with `--fail-on-warning --fail-on-risky`, so an
  assertion-less test fails CI.
- **TEST-3** Test namespaces are wired by the bootstrap: `Test\` → `tests/lib/`,
  `<AppNamespace>\Tests\` → `apps/<app>/tests/`. App tests must live there.

## Repository-policy rules (artifacts that must move with the code)

- **POL-1** Any change to `apps/*/src`, `core/src` or `package.json` ships with rebuilt,
  committed `dist/` (and regenerated `core/css/*.css`).
- **POL-2** Adding/renaming a PHP class ships with regenerated autoloaders
  (`build/autoloaderchecker.sh`, root dump built `--no-dev`).
- **POL-3** Controller/attribute changes ship with regenerated `openapi.json` /
  `apps/*/openapi*.json` (`build/openapi-checker.sh`).
- **POL-4** Psalm fixes either resolve the issue or commit updated
  `build/psalm-baseline*.xml`; stale baseline entries fail too. Code in `lib/unstable`
  (`psalm-ncu.xml`) and strict scope has no baseline — must be genuinely clean.
- **POL-5** No new root-level files: `build/files-checker.php` enforces an exact whitelist.
  Scratch artifacts belong outside the repo.
- **POL-6** Every new/renamed file needs an SPDX header (`AGPL-3.0-or-later` for code and
  docs) or a sibling `<file>.license`; a new app must be added to `psalm.xml`, registered
  in `.tx/config` unless listed in `$untranslatedApps`, and must not touch the `3rdparty`
  submodule locally.
- **POL-7** `.htaccess` must not be "fixed" by a running instance; `root .htaccess` edits
  are checked by `build/htaccess-checker.php`.

## Process / metadata rules

- **MET-1** Commits follow Conventional Commits with an app/component scope
  (`fix(files_sharing): …`); flag `fix: something` without scope as **minor**.
- **MET-2** AI-assisted commits carry an `Assisted-by: AGENT_NAME:MODEL_VERSION` trailer;
  a coding-agent `Signed-off-by` is a **blocker** (DCO is human-only); agents never add
  it.
- **MET-3** PRs should be single-purpose and small; a PR mixing refactor + feature +
  style churn is a **question/minor** suggesting a split.

## Output format

Produce exactly this structure (Markdown), nothing before or after it:

```
## AI review — <model>, run <UTC timestamp>

**Scope**: <N> files, +<A>/-<D>. **Coverage**: full | partial (<reason, e.g. diff truncated at M lines>).
**Summary**: <2–3 sentences>

### Findings

| # | Severity | Location | Rule | Finding | Suggested fix |
|---|----------|----------|------|---------|---------------|
| 1 | major | lib/Foo.php:42 | PHP-4 | … | … |

(no findings → write "No findings." and keep the summary)

### Notes
- <optional: what was skipped and why, uncertainties, questions to a human>
```

Total findings cap: 15, sorted blocker → major → minor → question; when capped, say how
many were dropped.
