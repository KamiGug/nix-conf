ARG BASE_IMAGE=docker.io/library/nginx:1.31
FROM ${BASE_IMAGE}

COPY --chmod=0755 secret-entrypoint.sh /usr/local/bin/secret-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/secret-entrypoint.sh", "/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
