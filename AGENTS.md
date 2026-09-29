<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Agent Guidelines for Nextcloud Server

Guidance for AI coding agents working in this repository. The content below was derived by
reading the code, the build scripts and the CI workflows — file paths are cited so you can
verify a claim instead of trusting it.

---

## What this repo is

Nextcloud **server** (version 35 on this branch, `version.php` → `$OC_Version = [35, 0, 0, 3]`):
an AGPL-3.0-or-later PHP + Vue monorepo holding the server core and ~33 bundled apps (files,
encryption, external storage, sharing, trashbin, versions, LDAP, WebDAV auth, settings, …).
Frontends for other products (Talk, Forms, …) live in their own repos under the Nextcloud org.

The PHP requirement is hard-gated in `lib/versioncheck.php`: **>= 8.3 and < 8.6**; outside that
range the app 500s before boot. `composer.json` pins `config.platform.php = 8.3`.

## First: a fresh checkout is not bootstrapped

No dependencies, no installed instance. Nothing runs until you bootstrap:

```bash
composer install          # PHP deps -> lib/composer (the vendor-dir is non-standard!)
npm ci                    # also runs build/demi.sh ci for both frontend trees
bash build/autoloaderchecker.sh   # regenerates root + per-app autoload classmaps
mkdir -p data && ./occ maintenance:install --database sqlite \
  --database-name nextcloud --database-user root --database-pass rootpassword \
  --admin-user admin --admin-pass admin
```

`occ` refuses to run as a user who does not own `config/config.php`. Dev environments:
`flake.nix` (+ `.envrc`; the PHP version is scraped out of `lib/versioncheck.php`) or
`.devcontainer/` (Apache + PHP 8.4 + postgres + adminer + mailhog; `setup.sh` installs via
`occ`). `composer serve` runs `php -S localhost:8080 -t ./`; `Caddyfile` is an alternative.
Entry points are `index.php` (web), `occ`→`console.php` (CLI), `remote.php` (WebDAV),
`ocs/v1.php`+`v2.php` (OCS API), `public.php` (public links), `status.php` (probe),
`cron.php` (job tick). `config/config.php` is generated and gitignored; `config.sample.php`
is the documented option reference.

## Layout

| Path | What it is |
|---|---|
| `lib/public/` (`OCP\`) | **Stable public API** — the only surface app code may depend on |
| `lib/unstable/` (`NCU\`) | Experimental API; members need `@experimental <version>` |
| `lib/private/` (`OC\`) | Implementation. Not for app consumption |
| `lib/private/legacy/` | Global `OC_*` classes, autoloaded under namespace `""` |
| `core/` (`OC\Core\`) | The core "app", including `OC\Core\Command\` occ commands |
| `apps/<app>/` | Bundled apps. **Non-bundled app dirs are git-ignored** and auto-skipped by every checker |
| `3rdparty/` | git submodule (`nextcloud/3rdparty`) — Sabre etc. Never edit locally |
| `build/` | All tooling: `demi.sh`, `frontend/`, `frontend-legacy/`, checkers, psalm configs + baselines |
| `dist/` | **Committed build output** (932 tracked files) |
| `tests/` | PHP unit tests for `lib/` + `core/`, Playwright specs, fixtures, config presets |

Several `apps/*` dirs may be git-ignored in a given checkout. When a checker mysteriously
skips your app, look at `git status --porcelain --ignored` — `autoloaderchecker`,
`psalm-checker`, `openapi-checker`, php-cs-fixer and `npm run sass` all key off
`git check-ignore`.

## The five non-obvious rules that break CI

These are the failures no local `composer test` will reveal.

1. **You must rebuild and commit `dist/`.** `.github/workflows/npm-build.yml:94` runs
   `npm ci && npm run build`, then fails if `git status --porcelain` is non-empty —
   *"Please recompile and commit the assets"*. Any edit to `apps/*/src`, `core/src` or
   `package.json` requires `npm run build`, which also regenerates the committed
   `core/css/*.css` via `sass` (`build/npm-post-build.sh`). Humans absorb this with the
   `/compile` PR command (`command-compile.yml` → `chore(assets): Recompile assets`).
2. **Adding or renaming any PHP class requires regenerated autoloaders.** Each app carries its
   own *committed* composer autoloader (`apps/files/composer/composer.json` maps
   `OCA\Files\` → `../lib/`). `build/autoloaderchecker.sh` dumps the root loader plus every
   shipped app and fails on a diff; the root dump must be `--no-dev` or the Bamarni bin
   plugin leaks into the autoloader and fails too.
3. **Touching a controller requires regenerating OpenAPI.** `openapi.json` and
   `apps/*/openapi*.json` are generated from PHP attributes by
   `bash build/openapi-checker.sh` (apps carrying a `.noopenapi` marker are skipped).
4. **Psalm baselines are part of the diff.** `static-code-analysis.yml:77,81` runs
   `composer run psalm -- --update-baseline` and then `git diff --exit-code -- . ':!lib/composer'`.
   Either fix the issue or commit the updated `build/psalm-baseline*.xml`. Stale entries fail
   as well: `psalm.xml:13` sets `findUnusedBaselineEntry="true"`. `psalm-ncu.xml` and
   `psalm-strict.xml` have **no** baseline, so code in their scope must be genuinely clean.
5. **Do not create new root-level files.** `build/files-checker.php` enforces an exact
   whitelist of the repo root — extra *and* missing entries both fail, with a message to
   "inform the release team". Scratch output belongs outside the repository.

Additionally: a new app must be added to `psalm.xml` (`build/psalm-checker.sh`), registered in
`.tx/config` unless it appears in `$untranslatedApps` (`build/translation-checker.php`), and
the `3rdparty` submodule must not lag the target branch (`block-outdated-3rdparty.yml`).
`build/htaccess-checker.php` fails if a running instance has rewritten the root `.htaccess`.

## PHP conventions that are actually enforced

- `declare(strict_types=1);` in every file; `#[\Override]` on parent/interface implementations.
- Tabs for indentation; `composer cs:fix` (php-cs-fixer with `nextcloud/coding-standard`).
- `iconv` is a banned function (`psalm.xml:137-139`).
- User-facing text uses `…` (U+2026), never three ASCII dots — `build/triple-dot-checker.php`.
- Every file needs an SPDX header, plus a sibling `<file>.license` where the format cannot
  carry a comment (JSON, PNG, …). `reuse.yml` gates this; verify with `reuse lint`.

```php
/**
 * SPDX-FileCopyrightText: <year> <name>
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
```

### Public API annotations

`build/psalm/OcpSinceChecker.php` (run by `composer psalm:ocp` over `lib/public`) requires
`@since` on every public class, method, constant and enum case. Deprecations name the
replacement inline — e.g. `lib/public/Template.php:23`:

```php
 * @since 8.0.0
 * @deprecated 32.0.0 Use \OCP\Template\ITemplateManager instead
```

`NCU\` (`lib/unstable`) is the graduation path: `@experimental 31.0.0` → `@deprecated 32.0.0`
→ promoted into `OCP\` (see `lib/unstable/Config/ValueType.php`).

### App anatomy and bootstrap

`appinfo/info.xml` declares `<dependencies><nextcloud min-version="35" max-version="35"/></dependencies>`
and registers commands, background jobs, settings, navigations and capabilities.
`lib/AppInfo/Application.php` implements `IBootstrap`: `register()` for
`registerEventListener` / `registerService` / `registerCapability` / `registerSearchProvider` /
… (apps/dav registers services with closures), `boot()` for `$context->injectFn(...)` side
effects. `apps/dav/lib/Server.php` is the outlier: Sabre plugins are added imperatively, in
order, in its constructor.

### Routing and controllers

Routes come from `appinfo/routes.php` (`routes` for web; `ocs` mounted under
`/ocs/v2.php/apps/<app>/`, see `lib/private/Route/Router.php:188`) or from `#[ApiRoute]` /
`#[FrontpageRoute]` attributes (`Router.php:181`). OCS controllers extend `OCSController`
(JSON/XML negotiation), web controllers extend `Controller`. Auth and CSRF are PHP attributes,
not docblocks: `#[NoAdminRequired]`, `#[PublicPage]`, `#[NoCSRFRequired]`, `#[CORS]`,
`#[BruteForceProtection]`, `#[PasswordConfirmationRequired]`, `#[OpenAPI(scope: ...)]`.

Return shapes are documented *in the type* so the spec extractor can read them:

```php
/**
 * @return DataResponse<Http::STATUS_OK, array{...}, array{}>|DataResponse<Http::STATUS_BAD_REQUEST, array{}, array{}>
 */
```

### Persistence and config

All DB access goes through `OCP\IDBConnection`; prefer query builders with
`createNamedParameter($v, IQueryBuilder::PARAM_INT)` over string interpolation. New code
should use `OCP\DB\QueryBuilder\ITypedQueryBuilder` (`@since 34.0.0`). Schema changes are
migrations at `apps/<app>/lib/Migration/Version<MMM>Date<YYYYMMDD>.php` (`changeSchema()` +
`postSchemaChange()`; recent ones use `#[AddColumn]` attributes). **`db_structure.xml` and
`appinfo/database.xml` no longer exist** — do not reintroduce them.
Use `IAppConfig` for app values (mind its lazy-load flags), `IConfig` for system config and
`IUserConfig` for user config; the app-value methods on `IConfig` are deprecated.

## Frontend: two toolchains, one command

`build/demi.sh` runs npm in `build/frontend` (Vue 3 + Vite) *and* `build/frontend-legacy`
(Vue 2 + Webpack) — its header comment explains that npm workspaces break with two Vue
versions. Root `npm run build|dev|watch|test|lint` is just demi. Root `vite.config.ts` is a
stub; `vitest.config.ts` delegates via `projects: ['build/frontend*']`.

Sources are reached through a **committed symlink farm** (`build/frontend/apps/settings ->
../../../apps/settings`), and which tree an app is symlinked into decides its toolchain
(`files`, `settings`, `files_sharing`, `workflowengine`, `updatenotification` and `core` are
the legacy ones). Entry points are a **hardcoded `modules` map**
(`build/frontend/vite.config.ts:10`, `build/frontend-legacy/webpack.modules.cjs`) — adding a
bundle means adding a symlink *and* a map entry.

PHP pulls a bundle by naming convention: `Util::addScript('settings', 'vue-settings-admin-mail')`
resolves through `lib/private/Template/JSResourceLocator.php:68` to
`dist/settings-vue-settings-admin-mail.mjs`.

Shared npm deps live **only** in root `package.json`; there are no per-app `package.json`
files. Use Pinia for new stores (Vuex survives only in `settings` / `user_status`) and the
`@nextcloud/*` helpers (`initial-state`, `event-bus`, `router`, `l10n`, `axios`, `dialogs`,
`@nextcloud/vue` v9). Linting runs per tree against baselines (`build/eslint-baseline.json`,
`build/eslint-baseline-legacy.json`); root `npm run lint` covers only `./tests/playwright`.
`apps/*/l10n/*` and generated `*.css` are not hand-editable — translations flow from Transifex.

## Testing

```bash
composer test                                            # full PHP suite
composer test -- tests/lib/Share20/ManagerTest.php       # one file
composer test -- ../apps/files/tests/Controller/ApiTest.php::testFoo
composer test:db                                         # --group DB --group SLOWDB
composer test:files_external                             # separate phpunit config
npm run test                                             # vitest, both frontend trees
npm run playwright:install && npm run playwright:setup && npm run playwright
bash autotest-checkers.sh                                # the 5 repo checkers
composer cs:check / lint / psalm / psalm:ocp / psalm:ncu / psalm:strict / psalm:security
```

PHPUnit 11.5 comes from `vendor-bin/phpunit` and lands in `lib/composer/bin`; the config is
`tests/phpunit-autotest.xml`, which suites `lib/`, `Core/` and `../apps/` recursively. It runs
with `--fail-on-warning --fail-on-risky`, so an assertion-less test fails. Test namespaces are
wired at runtime by the bootstrap: `Test\` → `tests/lib/`, and `<AppNamespace>\Tests\` →
`apps/<app>/tests/` (only under `PHPUNIT_RUN`), so app tests live in `apps/<app>/tests/`
mirroring `lib/`.

DB access is **gated**: `tests/lib/TestCase.php` fails a test that touches the database unless
it carries `#[Group('DB')]` or `#[Group('SLOWDB')]` (attributes, not `@group` annotations).
Tests run against a real installed instance — CI uses `tests/preseed-config.php` plus
`php -f tests/enable_all.php`, and both overwrite `config/config.php` and `data/`.
`autotest.sh` is the docker-driven multi-DB runner (`./autotest.sh sqlite [testfile]`, DBs:
sqlite/mysql/mariadb/pgsql/oci/mysqlmb4), and CI does **not** use it — it installs and calls
the composer scripts directly. `tests/lib/AllConfigTest.php` asserts every key in
`config/config.sample.php` is documented, so editing that file can break an unrelated test.

Per `.github/CONTRIBUTING.md`: changed or added code must be unit-tested, and refactoring to
enable testability alongside a bug fix is encouraged. New features still require manual testing
on a live instance by the human contributor — agent-executed steps are not a substitute.

## Contribution policy (CI-enforced)

Full text: [AI Contribution Policy](https://github.com/nextcloud/.github/blob/master/AI_POLICY.md)
and [Contribution Guidelines](https://github.com/nextcloud/.github/blob/master/CONTRIBUTING.md).

- **Conventional Commits**, scope matching the app or component: `fix(files_sharing): …`.
  Enforced by `block-unconventional-commits.yml`. Types: `feat`, `fix`, `refactor`, `test`,
  `docs`, `chore`, `perf`, `build`, `ci`.
- **`Assisted-by: AGENT_NAME:MODEL_VERSION`** trailer on every AI-assisted commit, plus a
  disclosure of AI tool use in the PR body (`ai-policy.yml`).
- Never add `Signed-off-by` — only the human contributor certifies the DCO.
- Do not autonomously open issues, submit PRs, post review comments or file security reports.
  Every contribution goes through a human. Suspected vulnerabilities go to
  [HackerOne](https://hackerone.com/nextcloud), never to GitHub issues, and AI-generated
  security findings need independent human verification.
- Do not write PR descriptions, review comments or issue reports for the contributor, and do
  not fully auto-resolve `good first issue` items.
- Keep PRs single-purpose and small; propose a logical split *before* opening one. Anything
  touching several subsystems, or where the right approach is unclear, warrants a ticket first.
- Verify dependency names against the actual registry before suggesting them — package names
  and access-control code are where models hallucinate. Manually re-read auth logic.
- Explicitly tell the contributor when a planned or completed action risks the AI policy,
  stating which rule is at stake; never proceed silently.
- Do not hand-edit generated or vendored artifacts: `dist/`, `apps/*/l10n/`, `openapi*.json`,
  `3rdparty/`, `lib/composer/`, `apps/*/composer/composer/`.

### Comments

Document the code, never the process that produced it. State behaviour, signatures and
constraints the code cannot express itself (an invariant, a workaround for a named bug). Do
not narrate self-explanatory code, and never write comments recording decisions, requests or
diff history ("changed X to Y", "as requested", "this fixes …") — that belongs in the commit
message or the PR discussion, where it cannot go stale. Match the comment density of the
surrounding code.

## Before reporting work as done

1. `git status --porcelain` — did you leave generated files (autoloaders, `dist/`, OpenAPI
   specs, psalm baselines) uncommitted?
2. Did the change add a PHP class, a route/controller, or a JS bundle? Then regenerate.
3. Run the checker that matches what you touched (`cs:check`, `psalm`, `autotest-checkers.sh`,
   the per-tree lint, `reuse lint`) — not just the unit tests.
4. Check that new user-facing wiring covers every context the component appears in: default
   authenticated view, public share pages, and embedded hosts such as the Smart Picker and
   reference widgets. When emitting an event, verify every consumer of that component handles it.
5. Nothing is verified until it has actually run. This tree ships without `node_modules`,
   `vendor` or an installed instance, so a "tests pass" claim requires bootstrapping first.

## Per-topic rule notes

- [`.cursor/rules/`](.cursor/rules/) — one short note per subsystem (routes, database, DI,
  config, logging, error handling, module boundaries, testing, dependencies), applied by file
  glob. Where a note and this file disagree, this file wins.
- [`.github/AI_REVIEW.md`](.github/AI_REVIEW.md) — the review ruleset with stable rule IDs,
  shared by the CI review bot and the local review tooling. Single source of truth for findings.

## Further reading

- [Local CONTRIBUTING.md](.github/CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) · [DESIGN.md](DESIGN.md)
- [contribute/](contribute/) — DCO, `HowToApplyALicense.md`
- [Developer Manual](https://docs.nextcloud.com/server/latest/developer_manual/)
