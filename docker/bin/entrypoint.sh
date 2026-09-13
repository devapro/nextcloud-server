#!/bin/bash
#
# SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Prepares the mounted checkout and installs Nextcloud if needed, then hands over
# to the container command (apache2-foreground). Safe to run repeatedly.

set -euo pipefail

readonly ROOT=/var/www/html
readonly WEB_USER=www-data

DATA_DIR="${NEXTCLOUD_DATA_DIR:-/var/www/data}"
APPS_EXTRA_DIR="${NEXTCLOUD_APPS_EXTRA_DIR:-/var/www/apps-extra}"
DB_HOST="${POSTGRES_HOST:-db}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-nextcloud}"
DB_USER="${POSTGRES_USER:-nextcloud}"
DB_PASSWORD="${POSTGRES_PASSWORD:-nextcloud}"
ADMIN_USER="${NEXTCLOUD_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${NEXTCLOUD_ADMIN_PASSWORD:-admin}"
APPS="${NEXTCLOUD_APPS:-viewer}"
DB_WAIT_TIMEOUT="${NEXTCLOUD_DB_WAIT_TIMEOUT:-60}"

log() {
	printf '[entrypoint] %s\n' "$*"
}

fail() {
	printf '[entrypoint] ERROR: %s\n' "$*" >&2
	exit 1
}

occ() {
	gosu_web php "${ROOT}/occ" --no-warnings "$@"
}

# occ drops privileges to the owner of config/config.php when started as root,
# but before the install that file does not exist yet, so be explicit.
gosu_web() {
	if [ "$(id -u)" = '0' ]; then
		setpriv --reuid="${WEB_USER}" --regid="${WEB_USER}" --clear-groups "$@"
	else
		"$@"
	fi
}

check_prerequisites() {
	if [ ! -f "${ROOT}/3rdparty/autoload.php" ]; then
		fail "3rdparty/ is empty. Run 'git submodule update --init' on the host and start again."
	fi

	if [ -z "$(ls -A "${ROOT}/dist" 2>/dev/null)" ]; then
		fail "dist/ is empty. Run 'npm ci && npm run build' on the host and start again."
	fi
}

# Only the named volumes are touched. The checkout is a bind mount owned by the
# host user; recursively chowning it would be slow and would surprise the host.
prepare_directories() {
	if [ "$(id -u)" != '0' ]; then
		return
	fi

	mkdir -p "${DATA_DIR}" "${APPS_EXTRA_DIR}"
	chown "${WEB_USER}:${WEB_USER}" "${DATA_DIR}" "${APPS_EXTRA_DIR}"
}

install_dev_config() {
	log "Installing config/dev.config.php"
	cp "${ROOT}/docker/config/dev.config.php" "${ROOT}/config/dev.config.php"

	if [ "$(id -u)" = '0' ]; then
		chown "${WEB_USER}:${WEB_USER}" "${ROOT}/config/dev.config.php" 2>/dev/null || true
	fi
}

wait_for_database() {
	log "Waiting for postgres at ${DB_HOST}:${DB_PORT}"

	local waited=0
	until PGPASSWORD="${DB_PASSWORD}" pg_isready \
		--host="${DB_HOST}" --port="${DB_PORT}" \
		--username="${DB_USER}" --dbname="${DB_NAME}" --quiet; do
		if [ "${waited}" -ge "${DB_WAIT_TIMEOUT}" ]; then
			fail "postgres at ${DB_HOST}:${DB_PORT} did not become ready within ${DB_WAIT_TIMEOUT}s."
		fi
		sleep 1
		waited=$((waited + 1))
	done

	log "Database is ready"
}

is_installed() {
	occ status --output=json 2>/dev/null | grep -q '"installed":true'
}

needs_db_upgrade() {
	occ status --output=json 2>/dev/null | grep -q '"needsDbUpgrade":true'
}

install_nextcloud() {
	log "Installing Nextcloud (admin user '${ADMIN_USER}', database '${DB_NAME}' on ${DB_HOST})"

	occ maintenance:install \
		--verbose \
		--database=pgsql \
		--database-name="${DB_NAME}" \
		--database-host="${DB_HOST}" \
		--database-port="${DB_PORT}" \
		--database-user="${DB_USER}" \
		--database-pass="${DB_PASSWORD}" \
		--admin-user="${ADMIN_USER}" \
		--admin-pass="${ADMIN_PASSWORD}" \
		--data-dir="${DATA_DIR}"
}

# master ships fewer apps than a release tarball, so the apps listed in
# alwaysEnabled of core/shipped.json are not all present. Enable the ones that
# are, pull the rest from the app store into the writable apps path.
enable_apps() {
	local app
	for app in ${APPS//,/ }; do
		if occ app:getpath "${app}" >/dev/null 2>&1; then
			log "Enabling app '${app}'"
			occ app:enable "${app}" || log "WARNING: could not enable '${app}'"
		else
			log "Installing app '${app}' from the app store"
			# Not fatal: on master the app store frequently has no release yet for
			# the in-development server version, and there may be no network at all.
			occ app:install "${app}" \
				|| log "WARNING: could not install '${app}'. No compatible app store release for this server version, or no network. See docker/README.md."
		fi
	done
}

main() {
	check_prerequisites
	prepare_directories
	install_dev_config
	wait_for_database

	if is_installed; then
		log "Instance is already installed"
		if needs_db_upgrade; then
			log "Version in the checkout is newer than the database, running upgrade"
			occ upgrade --no-interaction
		fi
	else
		install_nextcloud
	fi

	enable_apps

	occ maintenance:mode --off >/dev/null 2>&1 || true
	occ db:add-missing-indices >/dev/null 2>&1 || true

	log "Nextcloud is ready at http://localhost:${NEXTCLOUD_PORT:-8080}"
	exec "$@"
}

main "$@"
