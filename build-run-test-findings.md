<!--
 - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
 - SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Build, Run & Test — verified findings

Date: 2026-08-31 · Branch: `docker-plan` · Method: read-only exploration (no installs, no file changes, no build/test execution — builds and test runners modify tracked files such as `dist/`, `config/config.php`, `.htaccess`).

## 0. Environment actually present on this machine

| Tool | Required by repo | Found on host | Notes |
|---|---|---|---|
| PHP | 8.3–8.5 (`lib/versioncheck.php` rejects < 8.3 and >= 8.6; `composer.json` requires `^8.3`) | **not installed** | PHP 8.4.24 + Composer 2.10.2 exist **only inside** the running `nextcloud-dev-app-1` container |
| Node | `^24.0.0` (`engines` in all three `package.json` files) | v26.0.0 | Outside the declared range; no `engine-strict` in any `.npmrc`, so npm only warns (`EBADENGINE`), does not fail |
| npm | `^11.3.0` | 11.12.1 | OK |
| Docker / Compose | needed for the docker stack, Playwright e2e, and `autotest.sh` DB containers | 29.4.3 / v5.1.3 | `nextcloud-dev` stack **already running** (app :8080 healthy, adminer :8081, postgres 18, redis 8, cron) |
| nix / direnv | optional (`flake.nix`, `.envrc`) | **not installed** | the Nix dev-shell path is unavailable here |

Dependency state of this checkout (already done): `3rdparty` submodule initialized; root `node_modules` present; `build/frontend-legacy/node_modules` present; `build/frontend` intentionally has **no** dependencies (empty lockfile — resolves from root `node_modules`); `lib/composer/` populated (phpunit 11.5.50, psalm, behat, cs-fixer, rector); `config/config.php` + `config/dev.config.php` exist (instance already installed via the docker stack); `dist/` present and git-tracked.

---

## 1. BUILD

### 1a. Frontend (JS/CSS → `dist/`)

```bash
npm ci          # one-time; postinstall runs build/demi.sh ci → npm ci in build/frontend and build/frontend-legacy
npm run build   # production build
```

- `npm run build` = `build/demi.sh build` (Vite build for the Vue 3 frontend in `build/frontend`, then webpack for the Vue 2 frontend in `build/frontend-legacy`) + `postbuild` hook `build/npm-post-build.sh` (compiles SCSS via `npm run sass`, generates icons via `npm run sass:icons`, links sourcemap licenses).
- Dev variants: `npm run dev`, `npm run watch`; Make wrappers: `make dev-setup`, `make build-js-production`, `make watch-js`.
- **Not documented beyond `engines`:** Node `^24` / npm `^11.3`. The README never states a Node version.
- **Not documented:** the `sass` npm script shells out to `find` and `git check-ignore`, and `demi.sh`/`npm-post-build.sh` are POSIX shell scripts — a git checkout and a POSIX environment are hard requirements (fine on macOS/Linux; Windows needs WSL).
- **Not documented:** `dist/` is committed to git. CI (`npm-build.yml`) runs `npm ci && npm run build` and fails if the tree becomes dirty — rebuilt assets must be committed.
- **Not documented:** `build/frontend/` has no `node_modules` and that is correct — its `package.json` has zero dependencies; everything (Vue 3, Vite, Vitest) resolves from the root `node_modules`.

### 1b. PHP dependencies (dev tools → `lib/composer/`)

```bash
composer install   # vendor-dir is lib/composer; post-install runs `composer bin all install` (phpunit, psalm, behat, cs-fixer, rector, openapi-extractor from vendor-bin/*)
```

- Requires PHP `^8.3` plus extensions from `composer.json` `require`: apcu, ctype, curl, dom, fileinfo, gd, libxml, mbstring, openssl, pdo, posix, session, simplexml, xml, xmlreader, xmlwriter, zip, zlib.
- **On this machine** only possible inside the container (as documented in `docker/README.md`):

```bash
docker compose -f docker/docker-compose.yml exec -e COMPOSER_ALLOW_SUPERUSER=1 app composer install
git checkout -- lib/composer/composer   # required: a dev install rewrites tracked autoloader files; build/autoloaderchecker.sh rejects the diff
```

### 1c. Third-party PHP libs (`3rdparty/`)

```bash
git submodule update --init   # documented in README; already done here
```

---

## 2. RUN

### Option A — Docker compose dev stack (added on this branch; `docker/README.md`)

```bash
git submodule update --init
docker compose -f docker/docker-compose.yml up -d --build
# → http://localhost:8080  (admin / admin), Adminer on :8081
```

- Services: `app` (Apache + PHP 8.4, checkout bind-mounted), `cron`, `db` (postgres:18-alpine), `redis` (redis:8-alpine), `adminer`.
- Needs: Docker; non-empty `3rdparty/` and `dist/` (both already satisfied — `dist/` is committed, so **no frontend build is needed to boot**).
- Optional `docker/.env` (copy from `docker/.env.example`): `NEXTCLOUD_PORT`, `NEXTCLOUD_TRUSTED_DOMAINS`, `POSTGRES_*`, `PHP_VERSION`, `NEXTCLOUD_UID`/`NEXTCLOUD_GID` (Linux only), `XDEBUG_MODE`. All have compose defaults.
- **Status here: already up and healthy** (`nextcloud-dev-app-1` on :8080).

### Option B — PHP built-in server (host)

```bash
composer run serve   # → http://localhost:8080
```

- Runs `occ config:system:set overwrite.cli.url` then `php -S`.
- **Undocumented env vars** (only visible in `composer.json`): `NEXTCLOUD_HOST` (default `localhost`), `NEXTCLOUD_PORT` (default `8080`), `NEXTCLOUD_WORKERS` → `PHP_CLI_SERVER_WORKERS` (default `4`).
- Needs host PHP 8.3–8.5 with all extensions, `composer install`, and an installed instance (`occ maintenance:install` or the web wizard). **Not usable on this host — no PHP installed.**

### Option C — DevContainer / Codespaces (`.devcontainer/`)

- Open in VS Code with the Dev Containers extension; Apache + Postgres + Mailhog (:8025) + Adminer (:8080); admin/admin.
- **Doc drift:** `.devcontainer/README.md` claims Node 16 via nvm is sufficient for `make` — the `engines` fields now require Node `^24`.

### Option D — Nix flake (`flake.nix`, `.envrc`)

- `nix develop` (or direnv) provides pinned PHP (parsed from `lib/versioncheck.php`), Node (parsed from `package.json` engines), composer, ffmpeg, libreoffice, reuse, haze.
- **Completely undocumented** in the README; unavailable here (nix not installed).

---

## 3. TEST

### 3a. PHPUnit — PHP unit tests

Prerequisites: `composer install` (provides `lib/composer/bin/phpunit`, **>= 11.5 required**, 11.5.50 present) and an installed Nextcloud.

Canonical commands:

```bash
composer run test        # full suite, tests/phpunit-autotest.xml, --fail-on-warning --fail-on-risky
composer run test:db     # only DB/SLOWDB groups
```

CI setup sequence (from `phpunit-sqlite.yml`, needed before the suite boots):

```bash
mkdir data
cp tests/preseed-config.php config/config.php
./occ maintenance:install --verbose --database=sqlite --database-name=nextcloud \
    --database-user=root --database-pass=rootpassword --admin-user admin --admin-pass admin
php -f tests/enable_all.php
```

Legacy all-DB wrapper: `./autotest.sh sqlite [lib/template.php]` — installs Nextcloud itself, supports `sqlite mysql mariadb pgsql oci mysqlmb4`. **Env vars documented only inside the script:** `USEDOCKER=1` (spin up DB containers automatically), `COVERAGE=1`, `TEST_SELECTION=DB|NODB|QUICKDB|PRIMARY-s3|PRIMARY-azure|PRIMARY-swift`, `PHP_EXE`, `PHPUNIT_EXE`, `EXECUTOR_NUMBER`, `ENABLE_REDIS`, `PRIMARY_STORAGE_CONFIG=local|swift`. It moves `config/config.php` aside and restores it on exit, and uses `/dev/shm` for the datadir on Linux.

On this machine, only via the container (documented in `docker/README.md`):

```bash
docker compose -f docker/docker-compose.yml exec -w /var/www/html/tests app \
    php ../lib/composer/bin/phpunit -c phpunit-autotest.xml --no-coverage lib/AppFramework/Utility/SimpleContainerTest.php
```

Also undocumented: `tests/bootstrap.php` honors `CONFIG_DIR` and `TEST_DONT_LOAD_APPS`.

### 3b. Vitest — JS/TS unit tests

```bash
npm run test              # vitest run (root config aggregates the build/frontend + build/frontend-legacy projects)
npm run test:coverage
npm run test:watch
```

- Needs `npm ci` first; Node `^24` per engines (v26 here — works with EBADENGINE warnings only).

### 3c. Playwright — browser e2e tests

```bash
npm run playwright:install   # one-time: downloads chromium-headless-shell
npm run playwright           # auto-starts a throwaway Nextcloud Docker container on port 8042
npm run playwright:setup     # installation-wizard tests (@setup project)
npx playwright test tests/playwright/e2e/files/files-sidebar.spec.ts   # single spec
npx playwright test --ui     # interactive mode
```

- **Extra requirement, documented only in `tests/playwright/README.md`:** a running Docker daemon (the harness `@nextcloud/e2e-test-server` manages its own container) plus the one-time browser download.
- **Undocumented env vars** (only in `playwright.config.ts` / `start-nextcloud-server.js`): `NEXTCLOUD_PORT` (default 8042), `PLAYWRIGHT_SETUP`, `BRANCH`, `CI`.

### 3d. Behat — PHP integration tests

- The README says "Behat for PHP integration tests" but **never says where they live**: `build/integration/` (`features/`, `run.sh`, `run-docker.sh`).
- `cd build/integration && ./run.sh [--tags X] [scenario]` — needs an installed instance, host PHP, and `lib/composer/bin/behat` from `composer install`; starts its own `php -S` on port `8080 + $EXECUTOR_NUMBER`.

### 3e. Lint / static analysis

```bash
composer lint        # php -l over all PHP files
composer cs:check    # php-cs-fixer dry run (cs:fix to apply)
composer psalm       # plus psalm:ocp, psalm:ncu, psalm:strict, psalm:security
npm run lint         # eslint (root + both frontends via postlint)
npm run stylelint
composer openapi     # build/openapi-checker.sh
```

---

## 4. Summary — things that were NOT documented (or documented only in code)

| Requirement | Where it is actually specified |
|---|---|
| PHP must be **< 8.6** (upper bound) | `lib/versioncheck.php` only |
| Node `^24`, npm `^11.3` | `engines` of all three `package.json` files; not in README |
| `composer run serve` env vars `NEXTCLOUD_HOST` / `NEXTCLOUD_PORT` / `NEXTCLOUD_WORKERS` | `composer.json` only |
| `autotest.sh` env vars (`USEDOCKER`, `COVERAGE`, `TEST_SELECTION`, `EXECUTOR_NUMBER`, `PHP_EXE`, `PHPUNIT_EXE`, `ENABLE_REDIS`, `PRIMARY_STORAGE_CONFIG`) | script comments / CI workflows only |
| Playwright needs a Docker daemon + one-time `npm run playwright:install`; fixed port 8042 | `tests/playwright/README.md` (Docker), port only in `playwright.config.ts` |
| Dev `composer install` dirties tracked `lib/composer/composer/*` → `git checkout -- lib/composer/composer` | `docker/README.md` only |
| `dist/` is git-tracked; CI fails on a dirty post-build tree | `.github/workflows/npm-build.yml` only |
| `build/frontend/` has no dependencies by design (root-hoisted) | its (empty) `package-lock.json` only |
| Behat integration tests live in `build/integration/` | nowhere in docs |
| Nix flake dev shell | only `flake.nix` / `.envrc` exist |
| `.devcontainer` README's "Node 16 is sufficient" is stale | contradicts current `engines` |

## 5. Practical verdict for this machine

- **Build (frontend):** ready — `npm ci && npm run build` works with the installed Node 26 (engine warnings only).
- **Build (PHP deps):** host blocked (no PHP/composer) — use the running container.
- **Run:** the docker stack is already up at <http://localhost:8080> (admin/admin); `composer run serve` is impossible on the host.
- **Test:** Vitest and Playwright run on the host (Playwright uses the local Docker daemon); PHPUnit/Behat must run inside the `nextcloud-dev-app-1` container.
