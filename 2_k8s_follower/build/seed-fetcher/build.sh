#!/bin/bash
set -euo pipefail

# Instantiate the authenticator image & copy the authenticator binary to local dir
docker run -d \
    --name authenticator \
    --entrypoint sh \
    $AUTHENTICATOR_CLIENT_IMAGE \
    -c "sleep infinity"
docker cp authenticator:/bin/authenticator .
docker stop authenticator
docker rm authenticator

docker build -t seed-fetcher:latest .
rm authenticator
