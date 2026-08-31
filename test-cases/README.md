<!--
  - SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Main UI test cases (local Docker)

Manual / Chrome-connected test cases for the Nextcloud server checkout running via
[`docker/`](../docker/README.md).

## Environment

| Item | Value |
|------|-------|
| Base URL | http://localhost:8080 |
| Login URL | http://localhost:8080/index.php/login |
| Admin | `admin` / `admin` |
| Stack | `docker compose -f docker/docker-compose.yml up -d` |

Pretty URLs are not enabled in this stack — use `/index.php/…` paths.

## How these were derived

Cases were written and verified against a live instance (Nextcloud 35.0.0 beta 2) in
**Google Chrome** over Chrome DevTools Protocol (CDP on `127.0.0.1:9222`).
**Not** the mobile MCP.

Latest automated Chrome pass/fail log: [`chrome-verification.json`](./chrome-verification.json).

### Chrome Connect setup

1. Start Chrome with remote debugging (non-default profile required):

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-profile-nextcloud-chrome-mcp \
  --no-first-run --no-default-browser-check \
  "http://localhost:8080/index.php/login"
```

2. MCP config for Cursor is in [`.cursor/mcp.json`](../.cursor/mcp.json)
   (`chrome-devtools-mcp` → `--browserUrl http://127.0.0.1:9222`).
   Enable **chrome-devtools** under Cursor Settings → MCP, then reload the agent
   so Chrome tools are available (this CLI session currently only exposes `mobile`).

3. Alternative (personal Chrome, Chrome 144+): enable remote debugging at
   `chrome://inspect/#remote-debugging` and switch MCP args to `--autoConnect`.

## Suite

| ID | Title | Priority |
|----|-------|----------|
| [TC-01](TC-01-successful-login.md) | Successful login lands on Dashboard | P0 |
| [TC-02](TC-02-failed-login.md) | Failed login with wrong password | P0 |
| [TC-03](TC-03-logout.md) | Logout returns to login page | P0 |
| [TC-04](TC-04-files-list.md) | Files app lists user files | P0 |
| [TC-05](TC-05-create-folder.md) | Create a new folder | P0 |
| [TC-06](TC-06-upload-file.md) | Upload a file from device | P0 |
| [TC-07](TC-07-delete-and-trash.md) | Delete a file and see it in Deleted files | P0 |
| [TC-08](TC-08-shares-view.md) | Open Shared with others view | P1 |
| [TC-09](TC-09-create-account.md) | Admin creates a new account | P0 |
| [TC-10](TC-10-personal-security.md) | Personal Security settings are reachable | P1 |
