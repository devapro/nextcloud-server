---
description: Attribute routes, routes.php, OCS vs frontpage vs DAV, CSRF
globs: "**/{*Controller.php,routes.php,openapi.json,ResponseDefinitions.php}"
alwaysApply: false
---

# API and routes

Three HTTP stacks. Pick one.

1. **Frontpage** — `index.php` + `OCP\AppFramework\Controller` + `#[FrontpageRoute]` / `routes.php` `routes` key.
2. **OCS** — `ocs/v1.php`|`v2.php` + `OCSController` + `#[ApiRoute]` / `routes.php` `ocs` key. Same matcher, different envelope. v2.php includes v1.php.
3. **DAV** — `remote.php` → Sabre. Not AppFramework routing. JS uses `@nextcloud/files/dav`, not axios OCS.

## Pattern

`Router` loads **attributes first**, then `appinfo/routes.php`. Do not register the same `controller#action` in both (Symfony duplicate name).

**New endpoints:** method attributes. Do not add them to `routes.php`.

```php
#[NoAdminRequired]
#[ApiRoute(verb: 'GET', url: '/api/v1/user_status')]
public function getStatus(): DataResponse { ... }
```

- `#[ApiRoute]` → OCS (`TYPE_API`). `#[FrontpageRoute]` → index.php. Generic `#[Route(type: Route::TYPE_API)]` works; prefer the subclasses like core.
- Attribute scanner only sees **top-level** `lib/Controller/*Controller.php` (not nested dirs).
- Name is `{ocs.}{app}.{controller}.{action}` lowercase. `root` for OCS may be `/cloud`, `/core`, etc.
- Existing shipped APIs still live in `appinfo/routes.php` arrays. That file is **not** dead for files/dav/provisioning.

### Security defaults (attributes, not route-file keys)

- Logged in unless `#[PublicPage]`.
- **Admin** unless `#[NoAdminRequired]` / `#[SubAdminRequired]` / `#[AuthorizedAdminSetting]`.
- CSRF unless `#[NoCSRFRequired]`. OCS may skip CSRF if `OCS-APIREQUEST: true` or `Authorization: Bearer`. Browser clients still send the request token.
- Forgetting `NoAdminRequired` on a user API makes it admin-only.

### OpenAPI

Empty `ResponseDefinitions` class holds `@psalm-type` aliases. Controller: `@psalm-import-type … from ResponseDefinitions`, typed `DataResponse<Http::STATUS_OK, …>`, `200:` comments, optional `#[OpenAPI(scope: …)]`. Commit generated `openapi.json`. `SCOPE_IGNORE` for HTML/internal routes.

## Follow

- `apps/user_status/lib/Controller/UserStatusController.php` — `OCSController` + `#[ApiRoute]` + `#[NoAdminRequired]`.
- `apps/files/lib/Controller/ConversionApiController.php` — attribute-only, not in `routes.php`.
- `core/Controller/CSRFTokenController.php` — `#[FrontpageRoute]` + `PublicPage` + `NoCSRFRequired`.
- `apps/webhook_listeners/lib/Controller/WebhooksController.php` — `#[ApiRoute]` + `#[OpenAPI]` + psalm-import-type.
- `apps/files/src/actions/convertUtils.ts` — `generateOcsUrl(...)` + axios.

## Do not copy

- `apps/files/lib/Controller/ApiController.php` — unused `ApiRoute` import; URLs still only in `routes.php`.
- `core/routes.php` heartbeat via deprecated `IRouter::create`.
- `#[Route(type: Route::TYPE_API)]` when `#[ApiRoute]` exists (FilenamesController).
- Frontpage HTML GET without `#[NoCSRFRequired]` (412).
- Defining DAV URLs through AppFramework.

## MUST

- MUST add new HTTP APIs as attributes on `lib/Controller/*Controller.php`, not as a second copy in `routes.php`.
- MUST put `#[NoAdminRequired]` on user-facing methods.
- MUST keep `ResponseDefinitions` psalm types in sync with OpenAPI.
- MUST NOT use Symfony `#[Route]` from FrameworkBundle.
