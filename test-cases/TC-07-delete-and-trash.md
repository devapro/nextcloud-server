<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# TC-07 — Delete a file and see it in Deleted files

| Field | Value |
|-------|-------|
| Priority | P0 |
| Type | Functional / Files / Trash |
| App | files, files_trashbin |

## Preconditions

- Logged in as `admin`.
- A disposable file exists in All files (e.g. create via TC-06: `tc06-upload.txt`,
  or create `tc07-delete-me.txt`).

## Steps

1. In **All files**, open the actions menu for the target file.
2. Choose **Delete** (or **Delete file**).
3. Confirm the file disappears from All files.
4. Open **Deleted files** from the sidebar, or go to
   `http://localhost:8080/index.php/apps/files/trashbin`.

## Expected results

- File is no longer listed under All files.
- **Deleted files** view title contains **Deleted files**.
- The deleted file appears in the trash list.
- Empty-state copy (**No deleted files**) is **not** shown while the file remains in trash.
