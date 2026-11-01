ARG BASE_IMAGE=docker.io/library/postgres:18
FROM ${BASE_IMAGE}

COPY --chmod=0755 secret-entrypoint.sh /usr/local/bin/secret-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/secret-entrypoint.sh", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["postgres"]
