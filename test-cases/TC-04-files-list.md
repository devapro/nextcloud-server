<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-04 — Files app lists user files

| Field | Value |
|-------|-------|
| Priority | P0 |
| Type | Smoke / Files |
| App | files |

## Preconditions

- Logged in as `admin`.
- Default welcome file exists (fresh Docker install has `welcome.txt`).

## Steps

1. Open `http://localhost:8080/index.php/apps/files/`.
2. Wait for the file list to finish loading.
3. Inspect the left navigation and the main list.

## Expected results

- URL resolves under `/index.php/apps/files/` (e.g. `…/files/files`).
- Page title contains **All files - Files - Nextcloud**.
- Sidebar includes: **All files**, **Personal files**, **Recent**, **Favorites**,
  **Shares**, **Tags**, **Deleted files**, **Files settings**.
- Toolbar shows a **New** button.
- File list shows `welcome.txt` (or other existing files) with sortable columns
  **Name**, **Size**, **Modified**.
