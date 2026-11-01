ARG BASE_IMAGE=codeberg.org/forgejo/forgejo:16
FROM ${BASE_IMAGE}

COPY --chmod=0755 secret-entrypoint.sh /usr/local/bin/secret-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/secret-entrypoint.sh", "/usr/bin/entrypoint"]
CMD ["/usr/bin/forgejo"]
