<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-05 — Create a new folder

| Field | Value |
|-------|-------|
| Priority | P0 |
| Type | Functional / Files |
| App | files |

## Preconditions

- Logged in as `admin`.
- Files app open on **All files** (`/index.php/apps/files/`).
- Folder name `TC05-Folder` does not already exist (or pick a unique name).

## Steps

1. Click **New**.
2. Confirm the menu includes:
   - **Upload files** / **Upload folders**
   - **New folder**
   - (optional) **Create file request**, **Create templates folder**
3. Click **New folder**.
4. Enter name `TC05-Folder`.
5. Confirm creation (Enter / submit in the dialog).
6. Wait for the file list to refresh.

## Expected results

- Folder `TC05-Folder` appears in the All files list.
- Opening the folder shows an empty (or only default) contents view.
- No error toast is shown.
