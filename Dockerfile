FROM debian:unstable-20230612-slim

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl build-essential git-all libffi-dev libffi8 libgmp-dev \
      libgmp10 libncurses-dev libncurses5 libtinfo5 zlib1g-dev openssh-client

ADD get-ghcup.sh /get-ghcup.sh
ENV GHCUP_INSTALL_BASE_PREFIX=/usr/local
RUN BOOTSTRAP_HASKELL_MINIMAL=1 /bin/sh /get-ghcup.sh

ENV PATH="/usr/local/.ghcup/bin:$PATH"
ENV LANG="C.UTF-8" LANGUAGE="C.UTF-8" LC_ALL="C.UTF-8"

RUN ghcup install ghc 9.2.7 --set
RUN ghcup install stack 2.11.1 --set
RUN ghcup install cabal 3.6.2.0 --set
RUN ghcup install hls 2.0.0.0 --set

ADD install-tools.sh /install-tools.sh
ADD stack.yaml /stack.yaml
RUN /bin/sh /install-tools.sh

