#!/usr/bin/env bash
#
# trivy-scan.sh — scan container image(s) for OS/library vulnerabilities with Trivy.
#
# Uses a locally-installed `trivy` binary when one is available, otherwise falls
# back to the official `aquasec/trivy` Docker image so no host install is
# required. The same script is used locally and in CI so behaviour is identical.
#
# Usage:
#   ./trivy-scan.sh IMAGE [IMAGE...]   Scan one or more image references
#   ./trivy-scan.sh -h | --help        Show this help
#
# Examples:
#   ./trivy-scan.sh haskell-tools-beta
#   ./trivy-scan.sh ghcr.io/flipstone/haskell-tools:latest
#   TRIVY_EXIT_CODE=1 ./trivy-scan.sh haskell-tools-beta
#
# Environment variables (with defaults):
#   TRIVY_SEVERITY=HIGH,CRITICAL          Severities to report
#   TRIVY_EXIT_CODE=0                     Exit code when vulnerabilities are found
#                                         (0 = report only, 1 = fail)
#   TRIVY_IGNORE_UNFIXED=false            When true, skip vulnerabilities with no fix
#   TRIVY_IMAGE=aquasec/trivy:latest      Image used for the Docker fallback

set -euo pipefail

TRIVY_SEVERITY=${TRIVY_SEVERITY:-HIGH,CRITICAL}
TRIVY_EXIT_CODE=${TRIVY_EXIT_CODE:-0}
TRIVY_IGNORE_UNFIXED=${TRIVY_IGNORE_UNFIXED:-false}
TRIVY_IMAGE=${TRIVY_IMAGE:-aquasec/trivy:latest}

usage() {
  # Print the leading comment block (after the shebang) as help text.
  awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
}

# Resolve the Docker daemon's unix socket. Honour rootless / Docker Desktop
# setups where DOCKER_HOST points somewhere other than /var/run/docker.sock
# (e.g. unix:///run/user/1000/docker.sock).
docker_socket() {
  local host="${DOCKER_HOST:-}"
  if [[ -z "$host" ]]; then
    host=$(docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)
  fi
  case "$host" in
    unix://*) printf '%s' "${host#unix://}" ;;
    "")       printf '%s' "/var/run/docker.sock" ;;
    *)        printf '%s' "" ;; # tcp:// and friends — nothing to bind-mount
  esac
}

trivy_args=( image --severity "$TRIVY_SEVERITY" --exit-code "$TRIVY_EXIT_CODE" )
if [[ "$TRIVY_IGNORE_UNFIXED" == "true" ]]; then
  trivy_args+=( --ignore-unfixed )
fi

run_trivy() {
  local image_ref="$1"

  if command -v trivy >/dev/null 2>&1; then
    trivy "${trivy_args[@]}" "$image_ref"
    return
  fi

  # Docker fallback. Persist the vuln DB in a named volume so it is not
  # re-downloaded on every run, mount the docker socket so locally-built
  # images can be scanned by name, and reuse the host registry credentials.
  local docker_args=( run --rm -v trivy-cache:/root/.cache/ )

  # Mount the daemon socket at the default location and point the container at
  # it explicitly. The explicit DOCKER_HOST is important: a mounted
  # ~/.docker/config.json may pin a `currentContext` (e.g. "rootless") whose
  # metadata is not present in the container, which otherwise breaks resolution.
  local sock
  sock=$(docker_socket)
  if [[ -n "$sock" && -S "$sock" ]]; then
    docker_args+=( -v "$sock:/var/run/docker.sock" -e DOCKER_HOST=unix:///var/run/docker.sock )
  fi

  if [[ -f "$HOME/.docker/config.json" ]]; then
    docker_args+=( -v "$HOME/.docker/config.json:/root/.docker/config.json:ro" )
  fi
  docker "${docker_args[@]}" "$TRIVY_IMAGE" "${trivy_args[@]}" "$image_ref"
}

images=()
case "${1:-}" in
  "" | -h | --help)
    usage
    [[ -z "${1:-}" ]] && exit 1 || exit 0
    ;;
  *)
    images=( "$@" )
    ;;
esac

status=0
for ref in "${images[@]}"; do
  echo "==> Scanning $ref"
  if ! run_trivy "$ref"; then
    echo "!! Trivy reported findings or failed for $ref" >&2
    status=1
  fi
done

exit "$status"
