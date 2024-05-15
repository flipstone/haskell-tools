#!/usr/bin/env bash

set -e

. tool-versions.env

set_build_args() {
  BUILD_ARGS="--build-arg GHC_VERSION=$GHC_VERSION --build-arg STACK_VERSION=$STACK_VERSION --build-arg HLS_VERSION=$HLS_VERSION"
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


  RELEASE_DATE=$(date '+%Y-%m-%d')
  TAG_ROOT="ghcr.io/flipstone/haskell-tools:debian-stable-ghc-$GHC_VERSION-$RELEASE_DATE-$COMMIT_SHA"
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
    echo "Both $AMD_TAG and $ARM_TAG must be pushed to Github Container Registry BEFORE running this step."
    docker buildx imagetools create --tag $TAG_ROOT $AMD_TAG $ARM_TAG
    ;;
  *)
    echo "usage: ./build-image.sh build-local-beta|build-and-push-arch-tag|push-manifest"
    exit 1
esac;
