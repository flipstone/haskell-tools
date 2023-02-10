#!/usr/bin/env bash

set -e

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
TAG_ROOT="flipstone/haskell-tools:debian-unstable-ghc-9.2.5-$RELEASE_DATE-$COMMIT_SHA"
ARM_TAG="$TAG_ROOT"-arm64
AMD_TAG="$TAG_ROOT"-amd64
ARCH=$(arch)

case "$ARCH" in
  x86_64)
    ARCH_TAG="$AMD_TAG"
    ;;
  aarch64)
    ARCH_TAG="$ARM_TAG"
    ;;
  *)
    echo "Unrecognized architecture: $ARCH"
    exit 1
    ;;
esac

COMMAND=$1
export DOCKER_BUILDKIT=1

case $COMMAND in
  build-arch-tag)
    echo "Building $ARCH_TAG"
    docker build . \
      --tag $ARCH_TAG \
      --cache-from flipstone/haskell-tools \
      --build-arg 'BUILDKIT_INLINE_CACHE=1'
    ;;

  push-arch-tag)
    case "$COMMIT_SHA" in
      uncommitted)
        echo "Please commit your changes and build an image tagged with the commit sha before pushing the image for release"
        ;;
      *)
        echo "Pushing $ARCH_TAG for release"
        echo "Press enter to continue"
        read
        docker push $ARCH_TAG
        ;;
    esac
    ;;

  push-manifest)
    echo "Both $AMD_TAG and $ARM_TAG must be pushed to Docker Hub BEFORE running this step."
    echo "Press enter to continue"
    read
    docker manifest create $TAG_ROOT --amend $AMD_TAG --amend $ARM_TAG
    docker manifest push $TAG_ROOT
    ;;
  *)
    echo "usage: ./build-image.sh build-arch-tag|push-arch-tag|push-manifest"
    exit 1
esac;
