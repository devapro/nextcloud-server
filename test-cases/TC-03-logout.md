<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-03 — Logout returns to login page

| Field | Value |
|-------|-------|
| Priority | P0 |
| Type | Auth / Session |
| App | core |

## Preconditions

- Docker stack is up.
- User is logged in as `admin` (complete TC-01 first).
- Current page can be Dashboard or any authenticated app.

## Steps

1. Click the account avatar control in the header (**Settings menu** / `#user-menu`).
2. In the account menu, confirm entries such as:
   - **View profile** (or profile header)
   - **Personal settings**
   - **Administration settings**
   - **Log out**
3. Click **Log out**.

## Expected results

- Session ends and the browser is redirected to the login page
  (`/index.php/login` or equivalent login URL).
- Login form is visible again (**Account name or email**, **Password**, **Log in**).
- Opening `http://localhost:8080/index.php/apps/dashboard/` without logging in
  redirects back to login.
