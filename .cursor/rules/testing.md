---
description: PHPUnit TestCase, Group DB, Vitest specs, Playwright fixtures
globs: "**/{*Test.php,*.spec.ts,*.spec.js,tests/**,**/tests/**}"
alwaysApply: false
---

# Testing

## PHP (PHPUnit 11)

- File `*Test.php`. Extend `Test\TestCase` (`tests/lib/TestCase.php`), not raw `PHPUnit\Framework\TestCase`.
- Core: namespace `Test\...`. Apps: `OCA\{App}\Tests\...` (optional `Unit` / `Integration` subfolder).
- Methods: `testFoo(): void`. `setUp`/`tearDown` get `#[\Override]`.
- **DB access:** `#[Group('DB')]` (import `PHPUnit\Framework\Attributes\Group`). Without it, `IDBConnection` is stubbed to fail. `@group` docblocks still work; new tests use attributes.
- Mocks: `$this->createMock(Foo::class)` and `private Foo&MockObject $foo`. `getMockBuilder` only for partial mocks.
- Data providers: `public static function fooProvider(): array` + `#[DataProvider('fooProvider')]`.
- DI: `$this->overwriteService(IFoo::class, $mock)`. Helpers: `invokePrivate()`, `loginAsUser()`, `getUniqueID()`.
- Every test boots the server. “Unit” means no Group DB + mocks, not an isolated process.

## Follow (PHP)

- `tests/lib/Security/SecureRandomTest.php` — pure unit, static providers, attributes.
- `apps/user_status/tests/Unit/Controller/UserStatusControllerTest.php` — mocked collaborators, `createMock`, no Group DB.
- `apps/user_status/tests/Integration/Service/StatusServiceIntegrationTest.php` — `Integration/` + `#[Group('DB')]` + `Server::get`.
- `tests/lib/SystemTag/SystemTagManagerTest.php` — Group DB + real `IDBConnection`.

## JS (Vitest, not Jest)

- Colocate `*.spec.ts` next to source (`apps/files/src/**/*.spec.ts`). Import `{ describe, expect, test, vi } from 'vitest'`.
- Vue: `@vue/test-utils` (`mount`/`shallowMount`) **or** `@testing-library/vue`. Two Vitest trees exist (Vue 3 `build/frontend`, Vue 2 `build/frontend-legacy`).
- `vi.mock('@nextcloud/axios')` etc. Setup includes jest-dom matchers.

## Playwright e2e

- Import `test`/`expect` from `tests/playwright/support/fixtures/*` (e.g. `files-page.ts`). Do not construct page objects in specs when a fixture exists.
- Page objects live in `tests/playwright/support/sections/*Page.ts`. Locator methods stay sync; `waitForResponse` **before** the click.

## Follow (JS)

- `apps/files/src/actions/deleteAction.spec.ts` — colocated vitest + `vi.mock`.
- `tests/playwright/e2e/files/files.spec.ts` + `tests/playwright/support/fixtures/files-page.ts`.

## Do not copy

- `apps/user_status/tests/Unit/Db/UserStatusMapperTest.php` — real DB via `TestCase::$realDatabase` **without** `#[Group('DB')]` (bypasses the guard).
- Mixing `@group` annotations with attributes in new tests.
- Fully mocked tests tagged Group DB “because overwriteService” unless the test actually needs the DB.
- Constructing Playwright page objects inside specs when a fixture already injects them.
- Jest APIs (`jest.fn`) — this repo is Vitest.

## MUST

- MUST extend `Test\TestCase`.
- MUST add `#[Group('DB')]` if the test touches the database (including mappers).
- MUST write PHP tests that fail on a plausible behavior bug, not on wiring/field copies.
- MUST import Playwright `test`/`expect` from support fixtures.
