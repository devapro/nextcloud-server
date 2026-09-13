---
description: PHP error handling — OCS exceptions, middleware mapping, DAV
globs: "**/*.php"
alwaysApply: false
---

# Error handling

AppFramework is a custom middleware pipeline, not Symfony HttpKernel. Services throw typed `\Exception` subclasses. HTTP mapping lives in middleware `afterException`, not in controllers and not in a kernel listener.

## Pattern

- Domain/service code throws small typed exceptions (`OCP\Files\NotFoundException`, `OCP\AppFramework\Db\DoesNotExistException`, app `Exception\*`, `OCP\HintException`).
- **OCS controllers** (`OCSController`): catch domain exceptions and rethrow `OCP\AppFramework\OCS\OCS*Exception`. Success returns `DataResponse`. `OCSMiddleware` builds the OCS envelope.
- **Non-OCS JSON/page controllers**: return `JSONResponse`/`DataResponse`/`TemplateResponse` with `OCP\AppFramework\Http::STATUS_*`. Do not throw OCS exceptions.
- Unexpected exceptions bubble to `index.php` (HTML 500/503). Do not `catch (\Exception)` just to turn bugs into 4xx.
- Log unexpected failures with `['exception' => $e]`. Pass `$previous` when wrapping.
- DAV is Sabre: throw `Sabre\DAV\Exception\*` / `OCA\DAV\Connector\Sabre\Exception\*`. `ExceptionLoggerPlugin` debug-logs expected DAV errors.

OCS subclasses (status in `Exception::getCode()`):

| Exception | HTTP |
|---|---|
| `OCSBadRequestException` | 400 |
| `OCSForbiddenException` | 403 |
| `OCSNotFoundException` | 404 |
| `OCSPreconditionFailedException` | 412 |
| `OCSException($msg, 0)` | OCS 999 / v2 500 |

`HintException`: `$message` for logs, `$hint` translated for users. Uncaught → HTML **503**. OCS wraps as `OCSException($e->getHint(), $code ?: 403)`.

Security exceptions are thrown by `SecurityMiddleware`, not controllers.

## Follow

- `apps/user_status/lib/Controller/UserStatusController.php` — `DoesNotExistException` → `OCSNotFoundException`; app exceptions → `OCSBadRequestException`; `DataResponse` on success.
- `lib/private/AppFramework/Middleware/OCSMiddleware.php` — maps `OCSException` to V1/V2 envelope.
- `lib/private/AppFramework/Http/Dispatcher.php` — `afterException` pipeline; leftover DB transaction → warning + rollback.

## Do not copy

- `apps/files/lib/Controller/ApiController.php` `getThumbnail`/`updateFileTags`: `catch (\Exception)` returns 400/404 — bugs become client errors.
- `apps/files_sharing/lib/Controller/ShareAPIController.php` `createShare`: leftover `catch (\Exception)` → `OCSForbiddenException` (unexpected → 403); `LockedException` mapped to 404.
- `apps/settings/lib/Controller/UsersController.php` `setUserSettings`: error body with HTTP 200.
- `apps/provisioning_api/lib/Controller/UsersController.php`: legacy OCS codes 101–111 instead of HTTP subclasses; some paths throw raw `InvalidArgumentException` from OCS controllers.

## MUST

- MUST throw typed domain exceptions from services; MUST map them at the controller boundary (OCS throw / non-OCS Response).
- MUST NOT catch `\Exception` to invent a 4xx unless wrapping with log + a real 500/OCSException.
- MUST NOT throw Symfony `HttpException`.
- MUST NOT rely on automatic mapping of `NotFoundException`/`DoesNotExistException` to HTTP (only PublicShare HTML 404 does that).
