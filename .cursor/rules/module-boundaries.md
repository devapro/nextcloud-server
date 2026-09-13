---
description: OCP vs OC vs NCU vs OCA namespaces and cross-app coupling
globs: "**/*.{php,ts,js,vue}"
alwaysApply: false
---

# Module boundaries

Composer map (`composer.json`): `OCP\` = `lib/public`, `OC\` = `lib/private`, `NCU\` = `lib/unstable`, `OCA\{App}` = `apps/{app}/lib`.

## Pattern

- **New app code** depends on `OCP\*` (stable, `@since` / `#[Consumable]`). `NCU\*` is experimental (`@experimental` required) — acceptable only if you can break with the next major.
- Shipped filesystem apps (`files`, `files_sharing`, `dav`, `settings`) **do** import `OC\*` (View, Filesystem, storage wrappers, FilenameValidator extras). That is core-in-app-clothing, not a license for third-party apps.
- Cross-app PHP: prefer OCP events. Files UI plugins listen to `OCA\Files\Event\LoadSidebar` / `LoadAdditionalScriptsEvent` (de facto public, **not** OCP).
- Optional apps: `class_exists` / nullable ctor types / `IAppManager::isEnabledForUser`. **No** Composer requires between apps. info.xml does not declare PHP app-to-app deps.
- DI: app container forwards `OCP\`/`OC\` to the server; server forwards `OCA\` to the owning app. Not isolated bundles.
- Frontend: `@nextcloud/*` packages + `window.OCA.*` / `window.OCP.*` registries. Do not import another app’s `src/`.

`comments` is the clean in-tree example (OCP + Files events only). `files` Application registers `NCU\Sharing\ISharingRegistry` **and** `OC\Core\Sharing\*` types.

## Follow

- `apps/comments/lib/AppInfo/Application.php` — IBootstrap, OCP events, no `OC\`.
- `apps/files_reminders/lib/AppInfo/Application.php` — listens to `OCA\Files\Event\LoadAdditionalScriptsEvent` + OCP node/user events.
- `apps/files/src/main.ts` — `@nextcloud/*` + `window.OCA.Files` / `window.OCP.Files`.

## Do not copy (unless you are that subsystem)

- `apps/files/lib/Capabilities.php` injecting `OC\Files\FilenameValidator` despite `OCP\Files\IFilenameValidator`.
- `apps/files_sharing/lib/Controller/ShareAPIController.php` importing Circles/Deck/Federation/GSS classes directly.
- `NCU\Sharing\ISharingRegistry` typing against `OC\Sharing\ISharingLegacyBackend` (unstable API leaking private).
- `DIContainer` aliasing `OCP\WorkflowEngine\IManager` to `OCA\WorkflowEngine\Manager` (every app container hard-depends on that app).
- Legacy `OCP\Util::connectHook` / Symfony `GenericEvent` string events (`files_sharing` Helper / boot).

## MUST

- MUST use `OCP\*` from new/third-party app code. MUST NOT add `use OC\` unless filling an existing in-tree hole (storage wrappers, View, extra FilenameValidator methods).
- MUST treat NCU as breakable; MUST put `@experimental` on new NCU members.
- MUST NOT import another app’s JS modules; use `@nextcloud/files` or `window.OCA.*`.
- SHOULD listen to typed `IEventListener` registrations, not `Util::connectHook`.
