<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Nextcloud dev stack (docker compose)

A self-contained development and testing instance: Apache + PHP, PostgreSQL, Redis,
a background cron runner and Adminer. The checkout is bind-mounted, so edits to
`lib/`, `core/`, `apps/` and `dist/` take effect on the next request.

For an IDE-integrated environment (VS Code / Codespaces) see [`.devcontainer/`](../.devcontainer/)
instead. For the browser end-to-end suite see [`tests/playwright/`](../tests/playwright/),
which manages its own throwaway container.

## Quick start

From the repository root:

```bash
git submodule update --init                    # 3rdparty/, once per clone
docker compose -f docker/docker-compose.yml up -d --build
```

The first boot builds the image and runs `occ maintenance:install`; watch it with
`docker compose -f docker/docker-compose.yml logs -f app`. When it prints
`Nextcloud is ready`, open <http://localhost:8080> and log in as `admin` / `admin`.

`dist/` is committed, so no frontend build is needed to boot. Rebuild it only when
you change frontend sources — see [Frontend changes](#frontend-changes).

To use non-default ports, credentials or PHP version, copy `docker/.env.example` to
`docker/.env` and edit it. Every value there is also the compose default, so the
file is optional.

Tip: the `-f docker/docker-compose.yml` gets repetitive. Either export it once per
shell —

```bash
export COMPOSE_FILE=docker/docker-compose.yml
```

— or run the commands from inside `docker/`. The rest of this document assumes the
explicit `-f` form.

## Services

| Service   | Image / build       | Host address            | Purpose |
|-----------|---------------------|-------------------------|---------|
| `app`     | `docker/Dockerfile` | <http://localhost:8080> | Apache + PHP 8.4 serving the checkout |
| `cron`    | same image          | –                       | Runs `cron.php` every 5 minutes |
| `db`      | `postgres:18-alpine`| –                       | Database |
| `redis`   | `redis:8-alpine`    | –                       | Distributed cache and transactional file locking |
| `adminer` | `adminer:5`         | <http://localhost:8081> | Database browser |

Adminer's login form defaults to MySQL; use
<http://localhost:8081/?pgsql=db&username=nextcloud&db=nextcloud> to land on the
PostgreSQL form with the server pre-filled, then enter `POSTGRES_PASSWORD`.

## Credentials

| What | Value |
|------|-------|
| Nextcloud admin | `admin` / `admin` |
| PostgreSQL | `nextcloud` / `nextcloud`, database `nextcloud` |

Nextcloud's PostgreSQL setup creates its own least-privilege role, so
`config/config.php` ends up with `dbuser => oc_admin`, not `nextcloud`. Both roles
exist; use `nextcloud` for Adminer and `psql`.

## Everyday commands

```bash
DC="docker compose -f docker/docker-compose.yml"

$DC exec app php occ status                       # occ works as-is; see note below
$DC exec app php occ app:enable admin_audit
$DC exec app php occ config:system:set foo --value bar
$DC exec app php cron.php                         # run background jobs now
$DC logs -f app                                   # Nextcloud log (log_type = errorlog)
$DC exec db psql -U nextcloud nextcloud            # SQL prompt
$DC restart app                                    # reload PHP config / entrypoint

$DC down                                           # stop, keep the database
$DC down -v                                        # stop and delete data + database
```

`occ` drops privileges to the owner of `config/config.php` on its own, so
`exec app php occ` does not need `--user www-data`.

## Configuration

The stack never edits `config/config.php` by hand. Development settings live in
`docker/config/dev.config.php`, which the entrypoint copies to
`config/dev.config.php` on every start. Nextcloud merges all `config/*.config.php`
files on top of `config/config.php`, so these settings survive
`occ config:system:set` and stay out of the generated file.

It sets, among others, `debug => true` (required for a dev environment),
`log_type => errorlog` so the log lands in `docker compose logs`, Redis for
`memcache.distributed` and `memcache.locking`, and disables brute-force and rate
limiting so test suites can log in repeatedly.

Environment variables it reads (all set in `docker-compose.yml`, overridable in
`docker/.env`): `NEXTCLOUD_PORT`, `NEXTCLOUD_TRUSTED_DOMAINS`, `NEXTCLOUD_LOGLEVEL`,
`NEXTCLOUD_DATA_DIR`, `NEXTCLOUD_APPS_EXTRA_DIR`, `REDIS_HOST`, `REDIS_PORT`.

To reset an instance completely:

```bash
docker compose -f docker/docker-compose.yml down -v
rm -f config/config.php config/dev.config.php
```

## Testing

PHPUnit needs the dev dependencies, which are not in the image:

```bash
DC="docker compose -f docker/docker-compose.yml"
$DC exec -e COMPOSER_ALLOW_SUPERUSER=1 app composer install
$DC exec -w /var/www/html/tests app php ../lib/composer/bin/phpunit \
    -c phpunit-autotest.xml --no-coverage lib/AppFramework/Utility/SimpleContainerTest.php
git checkout -- lib/composer/composer
```

The last line matters: a dev `composer install` rewrites the tracked files under
`lib/composer/composer/`, and `build/autoloaderchecker.sh` rejects that diff.

`tests/bootstrap.php` boots every bundled app and logs a
`Could not boot admin_audit` warning before the first test. That is pre-existing
upstream noise, not a stack problem — the tests still run.

Coverage needs Xdebug in coverage mode:

```bash
XDEBUG_MODE=coverage docker compose -f docker/docker-compose.yml up -d app
```

The Playwright suite is independent of this stack and manages its own container
(`npm run playwright`, port 8042).

## Xdebug

Off by default. To enable it, set `XDEBUG_MODE` in `docker/.env` and recreate the
container — no rebuild needed, Xdebug reads the environment variable directly:

```bash
echo 'XDEBUG_MODE=debug,develop' >> docker/.env
docker compose -f docker/docker-compose.yml up -d app
```

The container connects back to `host.docker.internal:9003`, which matches
`.devcontainer/launch.json`, so the same "Listen for Xdebug" profile works.
`xdebug.start_with_request=trigger`, so a session only starts when the request
carries the `XDEBUG_TRIGGER` cookie or query parameter (any browser Xdebug helper
extension sets it).

## Frontend changes

Run the watcher on the host — it is far faster than inside a bind mount, and the
container picks up `dist/` immediately:

```bash
npm ci
npm run watch
```

Note that `dist/` is tracked, so a rebuild shows up in `git status`.

## Design notes

Things that are the way they are on purpose:

- **`.htaccess` is mounted read-only.** `occ maintenance:install` appends a rewrite
  block to the tracked root `.htaccess`, which `build/htaccess-checker.php` guards.
  The read-only mount makes the installer skip it. The cost is that pretty URLs are
  not enabled; everything is served under `/index.php/…`.
- **The data directory lives at `/var/www/data`,** in a named volume outside the
  checkout — `build/files-checker.php` rejects an unexpected top-level `data/`.
  It is also declared in `dev.config.php` because `Setup::getSystemInfo()` creates
  the *default* data directory before `--data-dir` is applied.
- **A second, writable apps path** (`/var/www/apps-extra`, served at `/apps-extra`)
  keeps app-store installs out of the tracked `apps/` directory. Same mechanism the
  Playwright harness uses.
- **imagick is not installed.** The current PECL release does not build against
  PHP >= 8.4. The admin overview will note it; only preview and favicon generation
  are affected. To add it, extend `docker/Dockerfile` once a compatible release is
  out.
- **`viewer` may fail to install.** It is `alwaysEnabled` in `core/shipped.json` but
  not shipped in this repository, and the app store often has no release for an
  in-development server version yet. The entrypoint warns and continues. To supply
  it manually, clone and build it into `apps-extra`:
  ```bash
  docker compose -f docker/docker-compose.yml exec app \
      git clone --depth 1 https://github.com/nextcloud/viewer /var/www/apps-extra/viewer
  ```
  then build its frontend and `occ app:enable viewer`.
- **Adding another database** is a compose profile plus one branch in
  `install_nextcloud()` in `docker/bin/entrypoint.sh`; the rest of the stack is
  database-agnostic.

## Troubleshooting

**`permission denied for table oc_…` on first boot.** A leftover database volume
from an earlier install whose tables belong to a different role. Reset with
`down -v` and remove `config/config.php` as shown above.

**The app container exits with `3rdparty/ is empty`.** Run
`git submodule update --init` on the host.

**Permission errors writing to the checkout (Linux hosts).** Bind-mount ownership
is enforced on Linux. Set `NEXTCLOUD_UID` / `NEXTCLOUD_GID` in `docker/.env` to
your `id -u` / `id -g` and rebuild with
`docker compose -f docker/docker-compose.yml build`.

**Mimetype migration notice in the admin overview.** Expected, and deliberately not
run automatically because it is slow:
`docker compose -f docker/docker-compose.yml exec app php occ maintenance:repair --include-expensive`.
