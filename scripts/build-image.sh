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
  if [ -n "$(git status --porcelain)" ]; then
    echo "Uncommitted changes found. Images will be tagged with -uncommitted"
    COMMIT_SHA="uncommitted"
  else
    COMMIT_SHA=$(git show-ref --hash=7 --verify HEAD)
  fi

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

  build-arch-tag)
    set_build_args
    set_tag_and_arch_variables
    echo "Building $ARCH_TAG without pushing (verification only)"
    docker buildx build . \
      "${BUILD_ARGS[@]}" \
      --tag "$ARCH_TAG" \
      --cache-from type=registry,ref="$CACHE_TAG"
    ;;

  push-manifest)
    set_tag_and_arch_variables
    echo "Both $AMD_TAG and $ARM_TAG must be pushed to GitHub Container Registry BEFORE running this step."
    docker buildx imagetools create --tag "$TAG_ROOT" "$AMD_TAG" "$ARM_TAG"
    ;;

  push-release-tag)
    set_tag_and_arch_variables
    if [ -z "$GITHUB_RUN_NUMBER" ]; then
      echo "GITHUB_RUN_NUMBER must be set (this command is meant to run in CI)"
      exit 1
    fi
    if [ "$COMMIT_SHA" = "uncommitted" ]; then
      echo "Refusing to publish a release tag from a dirty tree"
      exit 1
    fi
    # Release tags are what downstream Dependabot configs watch, so the
    # version must stay within a single dependabot-core tag format class.
    # A bare run number breaks at 1000 (dependabot-core#11198); leading
    # with the 4-digit year avoids that for good. Month and day are
    # unpadded on purpose: Dependabot compares segments numerically.
    #
    # The date is the commit's, not today's: a wall-clock date would let a
    # re-run of an old workflow mint a tag that sorts above newer releases
    # while pointing at an older image. With the commit date, a re-run
    # recreates the identical tag.
    COMMIT_DATE=$(TZ=UTC git show -s --format=%cd --date=format-local:%Y.%-m.%-d HEAD)
    RELEASE_TAG="ghcr.io/flipstone/haskell-tools:debian-ghc-$GHC_VERSION-build-$COMMIT_DATE.$GITHUB_RUN_NUMBER"
    echo "Publishing release tag $RELEASE_TAG (re-tag of $TAG_ROOT)"
    docker buildx imagetools create --tag "$RELEASE_TAG" "$TAG_ROOT"
    ;;

  scan-local-beta)
    mkdir -p trivy-reports
    docker compose run --rm trivy image haskell-tools-beta | tee trivy-reports/haskell-tools-beta.txt
    ;;

  scan-amd64-tag)
    set_tag_and_arch_variables
    echo "$AMD_TAG must be pushed to GitHub Container Registry BEFORE running this step."
    mkdir -p trivy-reports
    docker compose run --rm trivy image "$AMD_TAG" | tee trivy-reports/amd64.txt
    ;;
  *)
    echo "usage: ./scripts/build-image.sh build-local-beta|build-arch-tag|build-and-push-arch-tag|push-manifest|push-release-tag|scan-local-beta|scan-amd64-tag"
    exit 1
esac;
