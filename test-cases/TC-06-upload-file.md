<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-06 — Upload a file from device

| Field | Value |
|-------|-------|
| Priority | P0 |
| Type | Functional / Files |
| App | files |

## Preconditions

- Logged in as `admin`.
- Files app open on **All files**.
- A small local text file is available, e.g. `tc06-upload.txt` with any content.
- File with that name does not already exist in the current folder (or use a unique name).

## Steps

1. Click **New**.
2. Choose **Upload files** (or **Upload from device** / equivalent upload action).
3. Select `tc06-upload.txt` from the system file picker.
4. Wait for the upload to complete.

## Expected results

- `tc06-upload.txt` appears in the file list.
- Size and modified time are populated.
- File can be opened/downloaded without error.
