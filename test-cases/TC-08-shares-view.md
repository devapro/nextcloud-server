<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-08 — Open Shared with others view

| Field | Value |
|-------|-------|
| Priority | P1 |
| Type | Smoke / Sharing |
| App | files_sharing |

## Preconditions

- Logged in as `admin`.
- No prior shares are required for the empty-state path.

## Steps

1. Open Files (`/index.php/apps/files/`).
2. Open **Shares** in the sidebar, or navigate directly to
   `http://localhost:8080/index.php/apps/files/sharingout`.
3. Observe the **Shared with others** view.

## Expected results

- Page title contains **Shared with others - Files - Nextcloud** (or equivalent Shares view).
- View heading **Shared with others** is visible.
- If nothing was shared yet:
  - Message similar to **Nothing shared yet**
  - Helper text: **Files and folders you shared will show up here**
- Sidebar still offers navigation back to **All files**.
