<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-10 — Personal Security settings are reachable

| Field | Value |
|-------|-------|
| Priority | P1 |
| Type | Smoke / Settings |
| App | settings |

## Preconditions

- Logged in as `admin` (or any normal user).

## Steps

1. Open Account menu (avatar) → **Personal settings**, or go to
   `http://localhost:8080/index.php/settings/user`.
2. Confirm **Personal info** page loads.
3. In the personal settings navigation, click **Security**, or open
   `http://localhost:8080/index.php/settings/user/security`.
4. Inspect available security actions.

## Expected results

- Page title contains **Security - Personal settings - Nextcloud**.
- Section shows password change UI with **Change password**.
- Additional actions are present, e.g.:
  - **Add WebAuthn device**
  - **Create new app password**
- No fatal error / blank settings body.
