FROM haproxy:1.8

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -y && \
    apt-get install -y curl vim procps socat && \
    rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /docker-entrypoint.sh

COPY haproxy.cfg /usr/local/etc/haproxy/
COPY start.sh /
