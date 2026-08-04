#!/usr/bin/env bash

set -e

. tool-versions.env

set_build_args() {
  BUILD_ARGS="$(sed 's/^/--build-arg /' tool-versions.env)"
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
  ARCH=$(uname -m)

  case "$ARCH" in
    x86_64)
      ARCH_TAG="$AMD_TAG"
      ;;
    aarch64)
      ARCH_TAG="$ARM_TAG"
      ;;
    arm64)
      ARCH_TAG="$ARM_TAG"
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
    docker build . $BUILD_ARGS --tag haskell-tools-beta
    ;;

  build-and-push-arch-tag)
    set_build_args
    set_tag_and_arch_variables
    echo "Building $ARCH_TAG"
    docker buildx build . \
      $BUILD_ARGS \
      --tag $ARCH_TAG \
      --cache-from type=gha,mode=max,ignore-error=true \
      --cache-to type=gha,mode=max,ignore-error=true \
      --push
    ;;

  push-manifest)
    set_tag_and_arch_variables
    MANIFEST_TAGS="--tag $TAG_ROOT"

    # When PUBLISH_VERSION_TAG=true (set by CI for main-branch builds), also
    # publish a Dependabot-orderable version tag. The build number counts the
    # commits on the branch, so it increases monotonically on main and re-runs
    # of the same commit reproduce the same tag.
    if [ "${PUBLISH_VERSION_TAG:-false}" = "true" ]; then
      if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
        echo "PUBLISH_VERSION_TAG requires full git history to compute the build number (use fetch-depth: 0)."
        exit 1
      fi

      if [ "$COMMIT_SHA" = "uncommitted" ]; then
        echo "PUBLISH_VERSION_TAG requires a clean working tree."
        exit 1
      fi

      BUILD_NUMBER=$(git rev-list --count HEAD)
      VERSION_TAG="ghcr.io/flipstone/haskell-tools:debian-ghc-$GHC_VERSION-build-$BUILD_NUMBER"
      MANIFEST_TAGS="$MANIFEST_TAGS --tag $VERSION_TAG"
      echo "Also publishing version tag $VERSION_TAG"
    fi

    echo "Both $AMD_TAG and $ARM_TAG must be pushed to Github Container Registry BEFORE running this step."
    docker buildx imagetools create $MANIFEST_TAGS $AMD_TAG $ARM_TAG
    ;;

  scan-local-beta)
    ./trivy-scan.sh haskell-tools-beta
    ;;

  scan-arch-tags)
    set_tag_and_arch_variables
    echo "Both $AMD_TAG and $ARM_TAG must be pushed to Github Container Registry BEFORE running this step."
    ./trivy-scan.sh "$AMD_TAG" "$ARM_TAG"
    ;;
  *)
    echo "usage: ./build-image.sh build-local-beta|build-and-push-arch-tag|push-manifest|scan-local-beta|scan-arch-tags"
    exit 1
esac;
