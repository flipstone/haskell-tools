FROM debian:stable-20241016-slim

LABEL org.opencontainers.image.source="https://github.com/flipstone/haskell-tools"

ENV LANG="C.UTF-8" LANGUAGE="C.UTF-8" LC_ALL="C.UTF-8"

ARG DEBIAN_FRONTEND=noninteractive
ARG BOOTSTRAP_HASKELL_MINIMAL=1
ARG BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV GHCUP_INSTALL_BASE_PREFIX=/usr/local

ADD install-tools.sh /install-tools.sh

RUN apt-get update \
    && apt-get install -qq -y --no-install-recommends \
        curl build-essential git-all libffi-dev libffi8 libgmp-dev \
        libgmp10 libncurses-dev libncurses6 libtinfo6 zlib1g-dev openssh-client \
        procps libnuma-dev pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ~/.ssh/ && ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts

ADD https://get-ghcup.haskell.org /get-ghcup.sh
RUN /bin/sh /get-ghcup.sh

ENV PATH="/usr/local/.ghcup/bin:$PATH"

RUN ghcup config set url-source https://raw.githubusercontent.com/haskell/ghcup-metadata/master/ghcup-vanilla-0.0.8.yaml

# STACK_VERSION is managed in tool-versions.env
ARG STACK_VERSION
RUN ghcup install stack $STACK_VERSION --set

# GHC_VERSION is managed in tool-versions.env
ARG GHC_VERSION
RUN ghcup install ghc $GHC_VERSION --set

# HLS_VERSION is managed in tool-versions.env
ARG HLS_VERSION
RUN ghcup install hls $HLS_VERSION --set

# CABAL_VERSION is managed in tool-versions.env
ARG CABAL_VERSION
RUN ghcup install cabal $CABAL_VERSION --set

ADD stack.yaml /stack.yaml
RUN /bin/sh /install-tools.sh
