---
description: Where Nextcloud diverges from Symfony, Laravel, PSR, and typical PHP apps
alwaysApply: true
---

# Non-standard (read first)

This repo is a modular monolith with a hand-rolled AppFramework. Do not import Symfony/Laravel/Doctrine-ORM habits.

## Framework

- **Not Symfony HttpKernel.** No `HttpException`, ExceptionListener, or FrameworkBundle routing attributes. Mapping is `Middleware::afterException` (Django-like).
- **Not Symfony DI.** Pimple + reflection autowire. No YAML services, no compiler passes, no dumped container, no `#[Autowire]`. Unregistered instantiable classes resolve on `get()`.
- **Two containers** (server + per-app) routed by namespace prefix (`OCP\`/`OC\` vs `OCA\`), not bundle isolation.
- **Two-phase app boot:** `IBootstrap::register` then `boot`. `appinfo/app.php` is gone.
- PHP 8.4 lazy ghosts may delay constructors (`SimpleContainer::$useLazyObjects`).

## HTTP

- **Three stacks:** AppFramework frontpage (`index.php`), OCS (`ocs/v1.php`|`v2.php` XML/JSON envelope), Sabre DAV (`remote.php`).
- OCS v1: HTTP almost always 200; real status is `meta.statuscode` (OK = 100). OCS v2: HTTP ≈ exception code.
- CSRF is a **method attribute** default-on. OCS may bypass with `OCS-APIREQUEST` or Bearer. Not Laravel middleware groups / Symfony firewalls.
- Route names are invented from `Controller#method`, not developer-chosen Symfony names.
- Dual route registration: PHP 8 `#[ApiRoute]`/`#[FrontpageRoute]` **and** leftover `appinfo/routes.php`. New endpoints: attributes only.

## Data / config

- **No Doctrine ORM / Eloquent.** DBAL QueryBuilder + `QBMapper`/`Entity` (or a small Nextcloud ORM since 35 that is still QB). Table names unprefixed; `oc_` via `*PREFIX*`.
- **Not 12-factor.** Mutable `config.php` rewritten by the app. `NC_*` env is a string overlay. `*.config.php` merge then write-back strips comments from `config.php`.
- Secrets are **not** uniformly encrypted. `secret`/`dbpassword` sit plaintext in `config.php` and key `ICrypto`. App secrets encrypt only with `IAppConfig` `sensitive` / `FLAG_SENSITIVE`. Remote passwords: `ICredentialsManager`.
- `IConfig::getAppValue` does not decrypt sensitive appconfig.

## API surface

- Public API is a **parallel namespace** `OCP\` (`lib/public`), not `@internal` in the same package. Private is `OC\`. Experimental is `NCU\` (`lib/unstable`) with `@experimental`.
- Shipped apps (`files`, `dav`, `files_sharing`) import `OC\*` routinely. Third-party apps must not.
- Apps are directories, not Composer packages of each other. Cross-app: events + optional `class_exists`, never `require`.
- `OCP\EventDispatcher\Event` dropped the Symfony parent in NC 22. Leftover `GenericEvent` / `Util::connectHook` still exist — do not add more.

## Logging / errors

- Custom log sink + PSR-3 facade. **No Monolog.** Five stored levels; `critical` and `error` collapse. Channel is `context['app']`.
- `OCP\ILogger` is constants only (methods removed in 31). Inject `Psr\Log\LoggerInterface`.
- `HintException` uncaught → HTML **503**, not 500. User hint vs log message are separate fields.
- DAV errors are Sabre XML + `ExceptionLoggerPlugin` allowlist, not AppFramework.

## Frontend / tests

- Two JS build trees (Vue 3 Vite + Vue 2 webpack). No npm workspaces. `dist/` is committed.
- JS logger is `@nextcloud/logger`, not `console`. State: Pinia (newer) and Vuex (older) coexist.
- Cross-app JS: `@nextcloud/*` + `window.OCA.*` globals, not importing another app’s `src/`.
- PHPUnit 11 **boots the full server** for every test. `Test\TestCase` + `#[Group('DB')]` is the unit/integration split (DB is stubbed to fail otherwise). Not Symfony WebTestCase, not vanilla PHPUnit isolation.
- JS unit tests are **Vitest**, not Jest. E2E is Playwright with fixture-injected page objects.

## Practical

- Prefer boring in-tree patterns: `IBootstrap` + ctor injection + `QBMapper` + `#[ApiRoute]` + `OCS*Exception` + `LoggerInterface` + `IAppConfig`.
- When a Symfony/Laravel/Doctrine API looks useful, it is probably the wrong one here.
