#!/usr/bin/env bash

set -e -o pipefail

cd "$(dirname "$0")/.."

# shellcheck source=/dev/null
. tool-versions.env

set_build_args() {
  BUILD_ARGS=()
  while IFS= read -r version_assignment; do
    [ -n "$version_assignment" ] || continue
    BUILD_ARGS+=(--build-arg "$version_assignment")
  done < tool-versions.env
}

set_tag_and_arch_variables() {
  GIT_CHANGES=$(git status --porcelain | wc -l 2>/dev/null)

  case "$GIT_CHANGES" in
    0)
      COMMIT_SHA=$(git show-ref --hash=7 --verify HEAD)
      ;;
    *)
      echo "Uncommitted changes found. Images will be tagged with -uncommitted"
      COMMIT_SHA="uncommitted"
      ;;
  esac

  TAG_ROOT="ghcr.io/flipstone/haskell-tools:debian-ghc-$GHC_VERSION-$COMMIT_SHA"
  ARM_TAG="$TAG_ROOT"-arm64
  AMD_TAG="$TAG_ROOT"-amd64
  CACHE_ROOT="ghcr.io/flipstone/haskell-tools:buildcache"
  ARCH=$(uname -m)

  case "$ARCH" in
    x86_64)
      ARCH_TAG="$AMD_TAG"
      CACHE_TAG="$CACHE_ROOT"-amd64
      ;;
    aarch64)
      ARCH_TAG="$ARM_TAG"
      CACHE_TAG="$CACHE_ROOT"-arm64
      ;;
    arm64)
      ARCH_TAG="$ARM_TAG"
      CACHE_TAG="$CACHE_ROOT"-arm64
      ;;
    *)
      echo "Unrecognized architecture: $ARCH"
      exit 1
      ;;
  esac
}

COMMAND=$1

case $COMMAND in
  build-local-beta)
    set_build_args
    echo "Building haskell-tools-beta image"
    docker build . "${BUILD_ARGS[@]}" --tag haskell-tools-beta
    ;;

  build-and-push-arch-tag)
    set_build_args
    set_tag_and_arch_variables
    echo "Building $ARCH_TAG"
    # Layer cache lives in the registry rather than the GitHub cache
    # service, whose 10GB per-repo limit is far too small for this
    # image's layers and would thrash between the two architectures.
    docker buildx build . \
      "${BUILD_ARGS[@]}" \
      --tag "$ARCH_TAG" \
      --cache-from type=registry,ref="$CACHE_TAG" \
      --cache-to type=registry,ref="$CACHE_TAG",mode=max,ignore-error=true \
      --push
    ;;

  push-manifest)
    set_tag_and_arch_variables
    echo "Both $AMD_TAG and $ARM_TAG must be pushed to Github Container Registry BEFORE running this step."
    docker buildx imagetools create --tag "$TAG_ROOT" "$AMD_TAG" "$ARM_TAG"
    ;;

  scan-local-beta)
    mkdir -p trivy-reports
    docker compose run --rm trivy image haskell-tools-beta | tee trivy-reports/haskell-tools-beta.txt
    ;;

  scan-amd64-tag)
    set_tag_and_arch_variables
    echo "$AMD_TAG must be pushed to Github Container Registry BEFORE running this step."
    mkdir -p trivy-reports
    docker compose run --rm trivy image "$AMD_TAG" | tee trivy-reports/amd64.txt
    ;;
  *)
    echo "usage: ./scripts/build-image.sh build-local-beta|build-and-push-arch-tag|push-manifest|scan-local-beta|scan-amd64-tag"
    exit 1
esac;
