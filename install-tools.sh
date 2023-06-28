set -o errexit

stack install \
  --local-bin-path /usr/local/bin \
  weeder \
  fourmolu \
  ghcid \
  hlint \

rm -rf .stack-work /root/.stack
