FROM debian:unstable-20230109-slim

RUN apt-get update && apt-get install -y curl build-essential curl libffi-dev libffi8 libgmp-dev libgmp10 libncurses-dev libncurses5 libtinfo5 zlib1g-dev

ADD get-ghcup.sh /get-ghcup.sh
RUN BOOTSTRAP_HASKELL_MINIMAL=1 /bin/sh /get-ghcup.sh

ENV PATH="/root/.local/bin:/root/.ghcup/bin:$PATH"
ENV LANG="C.UTF-8" LANGUAGE="C.UTF-8" LC_ALL="C.UTF-8"

RUN ghcup install ghc 9.2.5 --set
RUN ghcup install stack 2.9.3 --set
RUN ghcup install cabal 3.6.2.0 --set
RUN ghcup install hls 1.9.0.0 --set

ADD install-tools.sh /install-tools.sh
ADD stack.yaml /stack.yaml
RUN /bin/sh /install-tools.sh

