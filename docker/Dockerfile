# SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
# SPDX-License-Identifier: AGPL-3.0-or-later

# Supported range is PHP >= 8.3 and < 8.6, see lib/versioncheck.php.
ARG PHP_VERSION=8.4

FROM php:${PHP_VERSION}-apache

# UID/GID of the web server user. The default 33 leaves the Debian `www-data`
# user untouched, which is what bind mounts on macOS and Windows need. On Linux,
# where bind-mount ownership is enforced, set UID/GID to your own ids in
# docker/.env so the container can write to the checkout.
ARG UID=33
ARG GID=33

# Extensions: the `require` list of composer.json plus the modules the admin
# manual recommends (intl, sysvsem) and the ones the bundled apps need (ldap for
# user_ldap, ftp for files_external). ctype, curl, dom, fileinfo, libxml,
# mbstring, openssl, posix, session, simplexml, sodium, xml, xmlreader,
# xmlwriter and zlib are already compiled into the base image.
#
# imagick is intentionally absent: the current PECL release does not build
# against PHP >= 8.4. It only affects preview generation for a few file types;
# see docker/README.md if you need it.
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		git \
		libbz2-dev \
		libfreetype6-dev \
		libgmp-dev \
		libicu-dev \
		libjpeg62-turbo-dev \
		libldap2-dev \
		libpng-dev \
		libpq-dev \
		libwebp-dev \
		libzip-dev \
		postgresql-client \
		unzip \
	; \
	docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
	docker-php-ext-configure ldap --with-libdir="lib/$(dpkg-architecture -q DEB_HOST_MULTIARCH)"; \
	docker-php-ext-install -j"$(nproc)" \
		bcmath \
		bz2 \
		exif \
		ftp \
		gd \
		gmp \
		intl \
		ldap \
		opcache \
		pcntl \
		pdo_pgsql \
		pgsql \
		sysvsem \
		zip \
	; \
	pecl install apcu redis xdebug; \
	docker-php-ext-enable apcu redis xdebug; \
	rm -rf /var/lib/apt/lists/*

RUN set -eux; \
	a2enmod dir env headers mime rewrite setenvif

COPY php/nextcloud-dev.ini php/xdebug.ini /usr/local/etc/php/conf.d/
COPY apache/nextcloud-dev.conf /etc/apache2/conf-enabled/

# For in-container `composer install` and the PHPUnit / Psalm / cs-fixer binaries
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN set -eux; \
	if [ "${UID}" != "33" ]; then usermod -o -u "${UID}" www-data; fi; \
	if [ "${GID}" != "33" ]; then groupmod -o -g "${GID}" www-data; fi; \
	# `occ` and the updater shell out to git; the checkout is owned by the host user
	git config --system --add safe.directory /var/www/html; \
	git config --system --add safe.directory /var/www/html/3rdparty

WORKDIR /var/www/html

# The entrypoint lives in the bind-mounted checkout so that editing it only needs
# a `docker compose restart`, not an image rebuild.
ENTRYPOINT ["/var/www/html/docker/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
