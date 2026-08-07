# Docker Hardened Images debian base (Community tier). The trixie-dev tag is
# rolling, so it is pinned by digest; dependabot bumps the digest monthly.
# Pulling requires `docker login dhi.io` (Docker Hub credentials).
FROM dhi.io/debian-base:trixie-dev@sha256:4440cf16b142316744a7fd1c5070eb23df54c7c335d8684c8d72864f0f3eb30e AS base

LABEL org.opencontainers.image.source="https://github.com/flipstone/haskell-tools"

ENV LANG="C.UTF-8" LANGUAGE="C.UTF-8" LC_ALL="C.UTF-8"

ENV GHCUP_INSTALL_BASE_PREFIX=/usr/local

# DEBIAN_FRONTEND=noninteractive is not set here because the DHI base bakes
# it in as a persistent ENV; restore it if this ever moves off DHI.
#
# The trailing ldconfig matters: the DHI base ships without /etc/ld.so.cache
# and apt does not regenerate it here, so without it tools that probe
# libraries via `ldconfig -p` (notably stack's GHC bindist selection) see an
# empty cache and misbehave.
RUN apt-get update \
    && apt-get install -qq -y --no-install-recommends \
        curl build-essential git libffi-dev libffi8 libgmp-dev \
        libncurses-dev libncurses6 zlib1g-dev openssh-client \
        procps libnuma-dev pkg-config jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig

RUN mkdir -p ~/.ssh/ && ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts

# GHCUP_VERSION is managed in tool-versions.env. A pinned ghcup binary is
# fetched directly rather than via the get-ghcup.haskell.org bootstrap
# script, which changes upstream and would invalidate every layer below
# this one whenever it does.
ARG GHCUP_VERSION
RUN mkdir -p /usr/local/.ghcup/bin \
    && curl --fail -o /usr/local/.ghcup/bin/ghcup \
      "https://downloads.haskell.org/~ghcup/${GHCUP_VERSION}/$(uname -m)-linux-ghcup-${GHCUP_VERSION}" \
    && chmod +x /usr/local/.ghcup/bin/ghcup

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

RUN tar --strip-components=1 --one-top-level=stack -x -z -f /stack.tar.gz
WORKDIR /stack
RUN stack build --copy-bins --local-bin-path /work

FROM base AS with-stack

COPY --from=build-stack /work/stack /usr/local/bin/stack
COPY image/container-stack-config.yaml /etc/stack/config.yaml

FROM with-stack AS with-ghc-cabal

# GHC_VERSION is managed in tool-versions.env
ARG GHC_VERSION
RUN ghcup install ghc "$GHC_VERSION" --set && ghcup gc --share-dir --tmpdirs --cache

# CABAL_VERSION is managed in tool-versions.env
ARG CABAL_VERSION
RUN ghcup install cabal "$CABAL_VERSION" --set && ghcup gc --share-dir --tmpdirs --cache

# Compiling HLS leaves a whole bunch of garbage around in /root/.cache
# and /root/.local This is purely so that HLS and the install tools can
# be run in parallel.
FROM with-ghc-cabal AS with-hls

# HLS_VERSION is managed in tool-versions.env
# Compling hls ensures that it will be compatible with the version of
# ghc we have installed. This way we are not dependent on matching the
# particular compiler versions that HLS has put in their bindist for
# a particular release. We make sure to remove the cache as part of
# building this layer to avoid extra space being taken up in the final
# image.
#
# The hls executable is dynamically linked against the .so libraries in
# the cabal store it was built from, so that store must ship in the
# image. XDG_STATE_HOME gives the build a store of its own: the default
# store (~/.local/state/cabal/store) is also where cabal builds run in
# downstream containers (as root) resolve already-installed packages,
# so it must not contain packages whose compile- and link-time
# artifacts have been pruned. With the store isolated, everything hls
# does not load at runtime (.a and .hi files) is deleted and the .so
# libraries are stripped.
ARG HLS_VERSION
RUN XDG_STATE_HOME=/usr/local/.ghcup/hls-cabal \
      ghcup compile hls -g "$HLS_VERSION" --ghc "$GHC_VERSION" --cabal-update -- --flags="-hlint" && \
    ghcup gc --share-dir --tmpdirs && \
    rm -rf ~/.cache && \
    find /usr/local/.ghcup/hls-cabal/cabal/store \( -name '*.a' -o -name '*.hi' -o -name '*.dyn_hi' \) -delete && \
    find /usr/local/.ghcup/hls-cabal/cabal/store -name '*.so' -exec strip --strip-unneeded '{}' + && \
    strip /usr/local/.ghcup/bin/haskell-language-server-*

# Each tool below is built in its own stage (all versions are managed in
# tool-versions.env) so that bumping one tool's version rebuilds only that
# tool, and so the builds run in parallel — with each other and with HLS,
# which none of them depend on. Every stage runs its own `cabal update` so
# a version bump always resolves against a current package index.
#
# We use cabal rather than stack to install these so that they can be
# versioned separately from the lts we're using -- especially if the
# version we want of a tool cannot compile with our lts. Since these
# tools are all binary executables copied into the final image they
# don't need to share dependency versions with each other or the lts.
#
# cabal does not strip the executables it installs, and the debug
# symbols account for roughly a third of each binary, so each stage
# strips what it built before the final image copies it in.

FROM base AS tool-ghciwatch
ARG GHCIWATCH_VERSION
RUN curl --fail -Lo /ghciwatch \
      "https://github.com/MercuryTechnologies/ghciwatch/releases/download/v${GHCIWATCH_VERSION}/ghciwatch-$(uname -m)-linux" \
    && chmod +x /ghciwatch

FROM with-ghc-cabal AS tool-weeder
ARG WEEDER_VERSION
RUN cabal update && cabal install --install-method=copy --installdir=/tool-bin "weeder-$WEEDER_VERSION" && strip /tool-bin/*

FROM with-ghc-cabal AS tool-fourmolu
ARG FOURMOLU_VERSION
RUN cabal update && cabal install --install-method=copy --installdir=/tool-bin "fourmolu-$FOURMOLU_VERSION" && strip /tool-bin/*

FROM with-ghc-cabal AS tool-ghcid
ARG GHCID_VERSION
RUN cabal update && cabal install --install-method=copy --installdir=/tool-bin "ghcid-$GHCID_VERSION" && strip /tool-bin/*

FROM with-ghc-cabal AS tool-hlint
ARG HLINT_VERSION
RUN cabal update && cabal install --install-method=copy --installdir=/tool-bin "hlint-$HLINT_VERSION" && strip /tool-bin/*

FROM with-ghc-cabal AS tool-shellcheck
ARG SHELLCHECK_VERSION
RUN cabal update && cabal install --install-method=copy --installdir=/tool-bin "ShellCheck-$SHELLCHECK_VERSION" && strip /tool-bin/*

FROM with-ghc-cabal AS tool-stan
ARG STAN_VERSION
RUN cabal update && cabal install --install-method=copy --installdir=/tool-bin "stan-$STAN_VERSION" && strip /tool-bin/*

FROM with-hls AS final

COPY --from=tool-ghciwatch /ghciwatch /usr/local/bin/ghciwatch
COPY --from=tool-weeder /tool-bin/weeder /usr/local/bin/weeder
COPY --from=tool-fourmolu /tool-bin/fourmolu /usr/local/bin/fourmolu
COPY --from=tool-ghcid /tool-bin/ghcid /usr/local/bin/ghcid
COPY --from=tool-hlint /tool-bin/hlint /usr/local/bin/hlint
COPY --from=tool-shellcheck /tool-bin/shellcheck /usr/local/bin/shellcheck
COPY --from=tool-stan /tool-bin/stan /usr/local/bin/stan
COPY image/run-stan.sh /usr/local/bin/run-stan
