<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-01 — Successful login lands on Dashboard

| Field | Value |
|-------|-------|
| Priority | P0 |
| Type | Smoke / Auth |
| App | core (login) → dashboard |

## Preconditions

- Docker stack is up (`app` healthy on port 8080).
- Browser is logged out (or use a fresh profile / incognito).
- Admin credentials: `admin` / `admin`.

## Steps

1. Open `http://localhost:8080/index.php/login`.
2. Confirm the page title contains **Login – Nextcloud**.
3. Confirm form shows:
   - **Account name or email**
   - **Password**
   - **Remember me**
   - **Log in**
4. Enter account name `admin`.
5. Enter password `admin`.
6. Click **Log in**.

## Expected results

- Browser navigates to `http://localhost:8080/index.php/apps/dashboard/`.
- Page title is **Dashboard - Nextcloud**.
- Main content shows **Dashboard**, greeting (**Hello**), and **Customize**.
- Header shows the admin avatar (e.g. **Avatar of admin**).
