---
description: Config stores, encryption, secrets, NC_ env, frontend masking
globs: "**/*.{php,js,ts,vue}"
alwaysApply: false
---

# Config and secrets

Four stores. Do not mix them.

| Layer | API | Storage | Encryption |
|---|---|---|---|
| System | `OCP\IConfig` get/setSystemValue* | `config/config.php` | **None** (plaintext) |
| App | `OCP\IAppConfig` (not deprecated IConfig app methods) | `appconfig` | Only if `sensitive=true` / lexicon `FLAG_SENSITIVE` |
| User | `OCP\Config\IUserConfig` | `preferences` | `FLAG_SENSITIVE` |
| Remote creds | `OCP\Security\ICredentialsManager` | `storages_credentials` | Always `ICrypto` |

## Pattern

- System: `IConfig::getSystemValueBool/Int/String`. `OC\SystemConfig` is bootstrap-only.
- App: typed `IAppConfig::setValueString/Int/Float/Array($app, $key, $value, $lazy, $sensitive)`. Register keys in app `ConfigLexicon` (`OCP\Config\Lexicon\ILexicon`) via `IRegistrationContext::registerConfigLexicon`.
- `IConfig::get/setAppValue` and `getUserValue` are **deprecated**; MIXED `getAppValue` **does not decrypt** sensitive values (returns ciphertext).
- Remote passwords: `ICredentialsManager::store($userId|'', $identifier, $creds)` with `#[SensitiveParameter]`. Mount `password` keys go through files_external `DBConfigService` + `ICrypto`.
- Env: `NC_{key}` overlays system config as **raw strings** (wins over files). No nested keys, no bool/array parse. `getSystemValueBool("false")` is truthy.
- Extra files: `config/*.config.php` natsort-merged; writes dump the **merged** cache back to `config.php` and strip comments. Put comments/constants in `*.config.php`.
- Diagnostics: `getFilteredSystemValue` / `getAllValues(..., filtered: true)` → `IConfig::SENSITIVE_VALUE`. `occ config:list` redacts unless `--private`.

## Frontend

MUST NOT put secrets in `provideInitialState` or `JSConfigHelper`. Mask like Mail (`********`) and OAuth2 (`clientSecret => ''`). There is **no** automatic secret filter on initial state.

## Follow

- `lib/private/Config.php` — merge + `NC_` overlay + write-back.
- `lib/private/SystemConfig.php` — redaction list (not encryption).
- `lib/private/Security/CredentialsManager.php` — encrypt JSON creds.
- `apps/files/lib/ConfigLexicon.php` — typed lexicon entries.
- `apps/settings/lib/Settings/Admin/Mail.php`, `apps/oauth2/lib/Settings/Admin.php` — mask secrets in UI.

## Do not copy

- `apps/user_ldap/lib/Configuration.php` — LDAP bind password via `IConfig::setAppValue` + base64 (not encryption).
- `apps/federation/lib/Settings/Admin.php` — `shared_secret` in initial state.
- Storing tokens with `IConfig::setAppValue` then reading them with `getAppValue` after they were written sensitive via IAppConfig.

## MUST

- MUST use `IAppConfig` + `sensitive: true` (or lexicon `FLAG_SENSITIVE`) for app tokens.
- MUST use `ICredentialsManager` for user/system remote passwords.
- MUST NOT commit `config/config.php` or `config/*.config.php`.
- MUST NOT log or ship secrets to JS.
- SHOULD treat `NC_*` as string overlays for immutable deploys, not a typed config tree.
