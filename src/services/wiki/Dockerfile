ARG BASE_IMAGE=docker.io/library/mediawiki:1.43
FROM ${BASE_IMAGE}
ARG MEDIAWIKI_BRANCH=REL1_43

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libpq-dev unzip; \
    docker-php-ext-install -j "$(nproc)" pgsql; \
    rm -rf /var/lib/apt/lists/*

COPY --from=docker.io/library/composer:2.10 /usr/bin/composer /usr/local/bin/composer

RUN set -eux; \
    cd /var/www/html/extensions; \
    git clone --depth 1 --branch 7.3.1 \
        https://github.com/SemanticMediaWiki/SemanticMediaWiki.git SemanticMediaWiki; \
    git clone --depth 1 --branch ${MEDIAWIKI_BRANCH} \
        https://gerrit.wikimedia.org/r/mediawiki/extensions/PageForms PageForms; \
    git clone --depth 1 --branch ${MEDIAWIKI_BRANCH} \
        https://gerrit.wikimedia.org/r/mediawiki/extensions/PluggableAuth PluggableAuth; \
    git clone --depth 1 --branch ${MEDIAWIKI_BRANCH} \
        https://gerrit.wikimedia.org/r/mediawiki/extensions/OpenIDConnect OpenIDConnect; \
    for ext in SemanticMediaWiki OpenIDConnect; do \
        cd "/var/www/html/extensions/$ext"; \
        COMPOSER_ALLOW_SUPERUSER=1 composer install \
            --no-dev --no-security-blocking --no-interaction --no-progress --no-plugins; \
        cd /var/www/html/extensions; \
    done; \
    chown -R www-data:www-data /var/www/html/extensions

RUN install -d -o www-data -g www-data -m 0755 /var/www/html/images

COPY --chmod=0755 setup.sh /usr/local/bin/mediawiki-setup
COPY --chmod=0755 secret-entrypoint.sh /usr/local/bin/secret-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/secret-entrypoint.sh", "/usr/local/bin/mediawiki-setup"]
CMD ["apache2-foreground"]
