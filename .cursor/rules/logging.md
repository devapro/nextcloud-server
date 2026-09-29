---
description: PSR-3 logging in PHP and @nextcloud/logger in JS
globs: "**/*.{php,js,ts,vue}"
alwaysApply: false
---

# Logging

## Pattern (PHP)

Constructor-inject `Psr\Log\LoggerInterface`. App DI wraps it in `OC\AppFramework\ScopedPsrLogger` so `context['app']` is the app id.

```php
$this->logger->error('Failed to list webhooks', ['exception' => $e]);
$this->logger->debug('Controller {class}::{method} created {count} QueryBuilder objects', [
    'class' => $class,
    'method' => $method,
    'count' => $n,
]);
```

- `OCP\ILogger` is **constants only** since 31 (`DEBUG=0` … `FATAL=4`). Do not inject it for logging methods.
- `OC\Log` is the private sink. Apps MUST NOT use it (exception: log-path admin UI).
- Prefer PSR-3 `{placeholders}` in the message. Put `Throwable` in `context['exception']`.
- Levels: `debug` noisy/trace; `info` audit-worthy events; `warning` leftover txn / high query counts; `error` failures with exception; `critical` PHP fatals. Default min level is WARN.
- Extra files: `OCP\Log\ILogFactory::getCustomPsrLogger` (admin_audit). There is no Monolog.

## Pattern (JS)

```ts
import { getLoggerBuilder } from '@nextcloud/logger'
export const logger = getLoggerBuilder().setApp('files').detectUser().build()
logger.error('Delete failed', { error, fileid })
```

## Follow

- `lib/private/AppFramework/DependencyInjection/DIContainer.php` — binds `LoggerInterface` → `ScopedPsrLogger`.
- `apps/webhook_listeners/lib/Controller/WebhooksController.php` — `error($msg, ['exception' => $e])`.
- `apps/files/src/utils/logger.ts` and `apps/files_reminders/src/shared/logger.ts` — `getLoggerBuilder().setApp(...).detectUser()`.
- `lib/private/AppFramework/Http/Dispatcher.php` — `{class}/{method}/{count}` placeholders.

## Do not copy

- `lib/private/BackgroundJob/Job.php` and `apps/dav/lib/Connector/Sabre/Auth.php` — `Server::get(LoggerInterface::class)` instead of injection.
- `apps/settings/lib/Controller/LogSettingsController.php` — injects `OC\Log` (only justified for `getLogPath`).
- `apps/workflowengine` logger mixing `ILogger::DEBUG` ints with `LoggerInterface::log`.
- Concatenating / `json_encode` of job arguments into the message (can leak secrets).
- `console.log` in shipped app production paths; use `@nextcloud/logger`.

## MUST

- MUST inject `LoggerInterface`; MUST NOT call `ILogger` log methods (removed).
- MUST put throwables in `['exception' => $e]`, not interpolated into the string.
- MUST NOT log passwords, tokens, or credential arrays (serializer redacts known methods; do not add new leaks).
