<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-02 — Failed login with wrong password

| Field | Value |
|-------|-------|
| Priority | P0 |
| Type | Negative / Auth |
| App | core (login) |

## Preconditions

- Docker stack is up.
- Browser is logged out.
- Known valid account: `admin` (password must **not** be used correctly in this case).

## Steps

1. Open `http://localhost:8080/index.php/login`.
2. Enter account name `admin`.
3. Enter password `wrong-password`.
4. Click **Log in**.

## Expected results

- URL remains on the login page (`/index.php/login`).
- An error message matching **Wrong login or password** is shown.
- Password field is marked invalid.
- User is **not** shown Dashboard or Files.
