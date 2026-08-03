#!/usr/bin/env bash
#
# One-time setup after cloning. Detects where the Docker daemon socket lives
# (rootless Docker and Docker Desktop put it somewhere other than
# /var/run/docker.sock) and records it as DOCKER_SOCK in .env, which
# docker compose reads automatically.

set -euo pipefail

cd "$(dirname "$0")/.."

host="${DOCKER_HOST:-}"
if [ -z "$host" ]; then
  host=$(docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)
fi
host="${host:-unix:///var/run/docker.sock}"

case "$host" in
  unix://*)
    sock="${host#unix://}"
    ;;
  *)
    echo "bootstrap.sh: docker daemon is at $host, not a unix socket; leaving DOCKER_SOCK at the default" >&2
    sock=/var/run/docker.sock
    ;;
esac

if [ ! -S "$sock" ]; then
  echo "bootstrap.sh: warning: $sock does not exist (is the docker daemon running?)" >&2
fi

touch .env
if grep -q '^DOCKER_SOCK=' .env; then
  sed -i.bak "s|^DOCKER_SOCK=.*|DOCKER_SOCK=$sock|" .env && rm .env.bak
else
  echo "DOCKER_SOCK=$sock" >> .env
fi

echo "Wrote DOCKER_SOCK=$sock to .env"

# The base image comes from Docker Hardened Images, which requires a login
# even for the free Community tier. Warn rather than fail so the rest of
# bootstrap is still useful without it.
docker_config="${HOME:-}/.docker/config.json"
if ! grep -q '"dhi.io"' "$docker_config" 2>/dev/null; then
  echo "bootstrap.sh: warning: not logged in to dhi.io (the base image registry)." >&2
  echo "  Run 'docker login dhi.io' with your Docker Hub credentials before building images." >&2
fi
