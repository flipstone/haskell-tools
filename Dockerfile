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
ADD https://github.com/flipstone/stack/archive/refs/tags/${STACK_VERSION}.tar.gz /stack.tar.gz

RUN tar --strip-components=1 --one-top-level=stack -x -z -f /stack.tar.gz && \
    cd stack && \
    stack build --copy-bins --local-bin-path /work

FROM base AS with-stack

COPY --from=build-stack /work/stack /usr/local/bin/stack
ADD container-stack-config.yaml /etc/stack/config.yaml

FROM with-stack AS with-ghc-cabal

# GHC_VERSION is managed in tool-versions.env
ARG GHC_VERSION
RUN ghcup install ghc $GHC_VERSION --set && ghcup gc --share-dir --tmpdirs --cache

# CABAL_VERSION is managed in tool-versions.env
ARG CABAL_VERSION
RUN ghcup install cabal $CABAL_VERSION --set && ghcup gc --share-dir --tmpdirs --cache

# Compiling HLS leaves a whole bunch of garbage around in /root/.cache
# and /root/.local This is purely so that HLS and the install tools can
# be run in parallel.
FROM with-ghc-cabal AS with-hls

# HLS_VERSION is managed in tool-versions.env
# Compling hls ensures that it will be compatible with the version of
# ghc we have installed. This way we are not dependent on matching the
# particular compiler versions that HLS has put in their bindist for
# a particular release. We cache sure to do cleanup as part of the layer
ARG HLS_VERSION
RUN ghcup compile hls -g $HLS_VERSION --ghc $GHC_VERSION --cabal-update && \
    ghcup gc --share-dir --tmpdirs && \
    rm -rf ~/.cache

# Run the install-tools step as a separate stage so that build remnants
# from stack-install don't end up in the final image. This does not
# depend on HLS, so we base this layer on the step before HLS above so
# that the two layers can be built in parallel.
FROM with-ghc-cabal AS with-tools

# GHCIWATCH_VERSION is managed in tool-versions.env
ARG GHCIWATCH_VERSION
ARG WEEDER_VERSION
ARG FOURMOLU_VERSION
ARG GHCID_VERSION
ARG HLINT_VERSION
ARG SHELLCHECK_VERSION
ARG STAN_VERSION
ADD install-tools.sh /install-tools.sh
RUN /bin/sh /install-tools.sh

FROM with-hls AS final

COPY --from=with-tools /install-tools-bins/* /usr/local/bin/.
ADD run-stan.sh /usr/local/bin/run-stan
