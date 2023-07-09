FROM debian:unstable-20230703-slim

ENV LANG="C.UTF-8" LANGUAGE="C.UTF-8" LC_ALL="C.UTF-8"

ARG DEBIAN_FRONTEND=noninteractive
ARG BOOTSTRAP_HASKELL_MINIMAL=1
ARG BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ARG GHCUP_INSTALL_BASE_PREFIX=/usr/local

ADD install-tools.sh /install-tools.sh

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    apt-get install -qq -y --no-install-recommends \
      curl build-essential git-all libffi-dev libffi8 libgmp-dev \
      libgmp10 libncurses-dev libncurses5 libtinfo5 zlib1g-dev openssh-client \
      procps libnuma-dev

RUN mkdir -p ~/.ssh/ && ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts

ADD get-ghcup.sh /get-ghcup.sh
RUN /bin/sh /get-ghcup.sh

ENV PATH="/usr/local/.ghcup/bin:$PATH"

RUN ghcup install cabal 3.10.1.0 --set
RUN ghcup install stack 2.11.1 --set
RUN ghcup install ghc 9.4.5 --set
RUN ghcup install hls 2.0.0.0 --set

ADD stack.yaml /stack.yaml
RUN /bin/sh /install-tools.sh

