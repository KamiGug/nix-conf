ARG BASE_IMAGE=docker.io/library/nextcloud:32
FROM ${BASE_IMAGE}

COPY --chmod=0755 secret-entrypoint.sh /usr/local/bin/secret-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/secret-entrypoint.sh", "/entrypoint.sh"]
CMD ["apache2-foreground"]
