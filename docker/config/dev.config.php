<?php

declare(strict_types=1);

/**
 * SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Development overrides for the docker/ stack. Nextcloud merges every
 * config/*.config.php on top of config/config.php, so these settings survive
 * `occ config:system:set` and never end up in the generated config file.
 *
 * docker/bin/entrypoint.sh copies this file to config/dev.config.php on start.
 * Do not use any of it on a production instance.
 */

$port = getenv('NEXTCLOUD_PORT') ?: '8080';
$host = 'localhost:' . $port;

$trustedDomains = ['localhost', $host];
$extraDomains = getenv('NEXTCLOUD_TRUSTED_DOMAINS');
if (is_string($extraDomains) && $extraDomains !== '') {
	$trustedDomains = array_merge(
		$trustedDomains,
		preg_split('/\s*,\s*/', $extraDomains, -1, PREG_SPLIT_NO_EMPTY) ?: [],
	);
}

$logLevel = getenv('NEXTCLOUD_LOGLEVEL');

$CONFIG = [
	// Also passed to `occ maintenance:install --data-dir`, but it has to be known
	// before the install too: Setup::getSystemInfo() mkdir's the *default* data
	// directory (SERVERROOT/data) to probe whether .htaccess protection works, and
	// build/files-checker.php rejects that stray directory in the checkout.
	'datadirectory' => getenv('NEXTCLOUD_DATA_DIR') ?: '/var/www/data',

	// Documented requirement for a development environment: renders exceptions with
	// a stack trace instead of a generic error page and disables asset caching
	'debug' => true,
	// Warning and above. Level 0 logs every query notice and buries the interesting
	// lines in `docker compose logs`; set NEXTCLOUD_LOGLEVEL=0 when chasing a bug.
	'loglevel' => is_string($logLevel) && $logLevel !== '' ? (int)$logLevel : 2,
	// Write to the PHP error log so the log ends up in `docker compose logs app`
	// rather than in a file inside the data directory
	'log_type' => 'errorlog',

	'trusted_domains' => array_values(array_unique($trustedDomains)),
	'overwrite.cli.url' => 'http://' . $host,
	'overwriteprotocol' => 'http',

	'memcache.local' => '\OC\Memcache\APCu',

	// The integration and end-to-end suites log in repeatedly and would otherwise
	// trip these protections
	'auth.bruteforce.protection.enabled' => false,
	'ratelimit.protection.enabled' => false,
	// Needed to create federated shares between two local instances
	'allow_local_remote_servers' => true,
	'sharing.federation.allowSelfSignedCertificates' => true,

	'updatechecker' => false,
];

// Redis provides the distributed cache and, more importantly, transactional file
// locking, which the in-database fallback only approximates.
$redisHost = getenv('REDIS_HOST');
if (is_string($redisHost) && $redisHost !== '') {
	$CONFIG['redis'] = [
		'host' => $redisHost,
		'port' => (int)(getenv('REDIS_PORT') ?: 6379),
	];
	$CONFIG['memcache.distributed'] = '\OC\Memcache\Redis';
	$CONFIG['memcache.locking'] = '\OC\Memcache\Redis';
}

// `apps` is a git-tracked directory, so it must stay read-only: anything the app
// store installs goes to a second, writable path outside the checkout. Without
// this, installing the always-enabled `viewer` app (absent from master) would
// leave untracked files in the working tree.
$appsExtra = getenv('NEXTCLOUD_APPS_EXTRA_DIR');
if (is_string($appsExtra) && $appsExtra !== '' && is_dir($appsExtra)) {
	$CONFIG['apps_paths'] = [
		[
			'path' => \OC::$SERVERROOT . '/apps',
			'url' => '/apps',
			'writable' => false,
		],
		[
			'path' => $appsExtra,
			'url' => '/apps-extra',
			'writable' => true,
		],
	];
}
