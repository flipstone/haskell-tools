#!/usr/bin/env bash
#
# trivy-scan.sh — scan container image(s) for OS/library vulnerabilities with
# Trivy. Used both locally (e.g. after `./build-image.sh build-local-beta`)
# and by the CI workflow, so behaviour is identical in both places.
#
# Run ./trivy-scan.sh --help for usage.

set -euo pipefail

TRIVY_SEVERITY=${TRIVY_SEVERITY:-HIGH,CRITICAL}
TRIVY_EXIT_CODE=${TRIVY_EXIT_CODE:-0}
TRIVY_IGNORE_UNFIXED=${TRIVY_IGNORE_UNFIXED:-false}
TRIVY_IMAGE=${TRIVY_IMAGE:-aquasec/trivy:0.73.0}

usage() {
  cat <<'EOF'
trivy-scan.sh — scan container image(s) for OS/library vulnerabilities with Trivy.

Uses a locally-installed `trivy` binary when one is available, otherwise falls
back to the official `aquasec/trivy` Docker image so no host install is
required.

Usage:
  ./trivy-scan.sh IMAGE [IMAGE...]   Scan one or more image references
  ./trivy-scan.sh -h | --help        Show this help

Examples:
  ./trivy-scan.sh haskell-tools-beta
  ./trivy-scan.sh ghcr.io/flipstone/haskell-tools:latest
  TRIVY_EXIT_CODE=1 ./trivy-scan.sh haskell-tools-beta

Environment variables (with defaults):
  TRIVY_SEVERITY=HIGH,CRITICAL      Severities to report
  TRIVY_EXIT_CODE=0                 Exit code when vulnerabilities are found
                                    (0 = report only, 1 = fail)
  TRIVY_IGNORE_UNFIXED=false        When true, skip vulnerabilities with no fix
  TRIVY_IMAGE=aquasec/trivy:<pin>   Image used for the Docker fallback

Any other exported TRIVY_* variable trivy understands (e.g. TRIVY_USERNAME,
TRIVY_PASSWORD, TRIVY_PLATFORM) is honoured by both the local binary and the
Docker fallback.
EOF
}

# Resolve how to reach the Docker daemon. Honour rootless / Docker Desktop
# setups where DOCKER_HOST (or the current context) points somewhere other
# than /var/run/docker.sock (e.g. unix:///run/user/1000/docker.sock).
docker_host() {
  local host="${DOCKER_HOST:-}"
  if [[ -z "$host" ]]; then
    host=$(docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)
  fi
  printf '%s' "${host:-unix:///var/run/docker.sock}"
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

  if ! command -v docker >/dev/null 2>&1; then
    echo "trivy-scan.sh: neither trivy nor docker is installed; install one of them to scan images" >&2
    return 1
  fi

  # Docker fallback. Persist the vuln DB in a named volume so it is not
  # re-downloaded on every run. TRIVY_CACHE_DIR pins the cache to the mounted
  # volume no matter which user the trivy image runs as.
  local docker_args=( run --rm -v trivy-cache:/trivy-cache -e TRIVY_CACHE_DIR=/trivy-cache )

  # Forward exported TRIVY_* configuration (credentials, platform, ...) so the
  # fallback honours the same variables the local binary would. TRIVY_IMAGE
  # only configures this script, and TRIVY_CACHE_DIR is set above.
  local var
  for var in $(compgen -A export TRIVY_ || true); do
    case "$var" in
      TRIVY_IMAGE | TRIVY_CACHE_DIR) ;;
      *) docker_args+=( -e "$var" ) ;;
    esac
  done

  # Give the container access to the daemon so locally-built images can be
  # scanned by name. A unix socket is mounted at the default location and
  # pointed at explicitly — a mounted ~/.docker/config.json may pin a
  # `currentContext` (e.g. "rootless") whose metadata is not present in the
  # container, which would otherwise break resolution. A tcp:// daemon is
  # reachable from inside the container as-is.
  local host
  host=$(docker_host)
  case "$host" in
    unix://*)
      local sock="${host#unix://}"
      if [[ -S "$sock" ]]; then
        docker_args+=( -v "$sock:/var/run/docker.sock" -e DOCKER_HOST=unix:///var/run/docker.sock )
      fi
      ;;
    tcp://*)
      docker_args+=( -e DOCKER_HOST="$host" )
      ;;
    *)
      echo "trivy-scan.sh: DOCKER_HOST=$host is not reachable from inside the trivy container; only registry image references will resolve" >&2
      ;;
  esac

  # Reuse the host registry credentials, but only when they are stored inline
  # in the config file. A config that delegates to credsStore/credHelpers is
  # unusable inside the container (the docker-credential-* helper binaries are
  # not installed there) and would make trivy error out instead of falling
  # back to anonymous access.
  local docker_config="${HOME:-}/.docker/config.json"
  if [[ -n "${HOME:-}" && -f "$docker_config" ]] \
    && ! grep -qE '"(credsStore|credHelpers)"' "$docker_config"; then
    docker_args+=( -v "$docker_config:/root/.docker/config.json:ro" )
  fi

  docker "${docker_args[@]}" "$TRIVY_IMAGE" "${trivy_args[@]}" "$image_ref"
}

images=()
for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "trivy-scan.sh: unknown option: $arg (scan options are set via TRIVY_* environment variables)" >&2
      exit 1
      ;;
    *)
      images+=( "$arg" )
      ;;
  esac
done

if [[ ${#images[@]} -eq 0 ]]; then
  usage >&2
  exit 1
fi

status=0
for ref in "${images[@]}"; do
  echo "==> Scanning $ref"
  if ! run_trivy "$ref"; then
    echo "!! Trivy reported findings or failed for $ref" >&2
    status=1
  fi
done

exit "$status"
