<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-09 — Admin creates a new account

| Field | Value |
|-------|-------|
| Priority | P0 |
| Type | Functional / Admin |
| App | settings (users) |

## Preconditions

- Logged in as `admin`.
- Account id `tc09user` does not already exist (or use a unique id).

## Steps

1. Open `http://localhost:8080/index.php/settings/users`
   (or Account menu → **Accounts**).
2. Confirm page title contains **All accounts**.
3. Confirm **New account** is available.
4. Click **New account**.
5. Fill required fields (account name / display name / password as prompted), e.g.:
   - Account: `tc09user`
   - Password: a valid password meeting policy
6. Submit / create the account.
7. Locate the new account in **All accounts** (search if needed).

## Expected results

- New account appears in the accounts list.
- Group counters / **All accounts** list refresh without error.
- Logging out and logging in as `tc09user` with the chosen password succeeds
  (optional verification; may land on Dashboard or first-run tips).
