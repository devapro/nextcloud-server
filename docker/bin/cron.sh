#!/bin/bash
#
# SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Background job runner for the docker/ stack: the same thing a real instance
# gets from a system cron entry every 5 minutes. Without it, background jobs only
# run when a browser tab happens to trigger AJAX cron.

set -euo pipefail

readonly ROOT=/var/www/html
readonly WEB_USER=www-data

INTERVAL="${NEXTCLOUD_CRON_INTERVAL:-300}"

log() {
	printf '[cron] %s\n' "$*"
}

run_as_web_user() {
	if [ "$(id -u)" = '0' ]; then
		setpriv --reuid="${WEB_USER}" --regid="${WEB_USER}" --clear-groups "$@"
	else
		"$@"
	fi
}

log "Waiting for the app container to finish installing"
until run_as_web_user php "${ROOT}/occ" --no-warnings status --output=json 2>/dev/null | grep -q '"installed":true'; do
	sleep 5
done

log "Running cron.php every ${INTERVAL}s"
while true; do
	if run_as_web_user php -f "${ROOT}/cron.php"; then
		log "cron.php finished"
	else
		log "WARNING: cron.php exited non-zero"
	fi
	sleep "${INTERVAL}"
done
