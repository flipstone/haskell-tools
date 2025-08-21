FROM debian:trixie-20250721-slim AS base

LABEL org.opencontainers.image.source="https://github.com/flipstone/haskell-tools"

ENV LANG="C.UTF-8" LANGUAGE="C.UTF-8" LC_ALL="C.UTF-8"

ARG DEBIAN_FRONTEND=noninteractive
ARG BOOTSTRAP_HASKELL_MINIMAL=1
ARG BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV GHCUP_INSTALL_BASE_PREFIX=/usr/local

RUN apt-get update \
    && apt-get install -qq -y --no-install-recommends \
        curl build-essential git-all libffi-dev libffi8 libgmp-dev \
        libgmp10 libncurses-dev libncurses6 libtinfo6 zlib1g-dev openssh-client \
        procps libnuma-dev pkg-config jq wget file \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p ~/.ssh/ && ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts

ADD https://get-ghcup.haskell.org /get-ghcup.sh
RUN /bin/sh /get-ghcup.sh

ENV PATH="/usr/local/.ghcup/bin:$PATH"

FROM base AS build-stack

# The prior release of stack (on ghcup) to the one that we're
# about to compile. Compiling the latest stack with itself caused
# a dependency version conflict related to the version of Cabal that
# was installed.
RUN ghcup install stack 3.5.1 --set

# STACK_VERSION is managed in tool-versions.env
ARG STACK_VERSION
RUN git clone https://github.com/flipstone/stack.git && \
    cd stack && \
    git checkout $STACK_VERSION && \
    stack build --copy-bins --local-bin-path /work

FROM base AS final

COPY --from=build-stack /work/stack /usr/local/bin/stack

# GHC_VERSION is managed in tool-versions.env
ARG GHC_VERSION
RUN ghcup install ghc $GHC_VERSION --set

# CABAL_VERSION is managed in tool-versions.env
ARG CABAL_VERSION
RUN ghcup install cabal $CABAL_VERSION --set

# HLS_VERSION is managed in tool-versions.env
ARG HLS_VERSION
RUN ghcup install hls $HLS_VERSION --set

ADD stack.yaml /stack.yaml

ADD install-tools.sh /install-tools.sh
RUN /bin/sh /install-tools.sh

ADD run-stan.sh /usr/local/bin/run-stan
