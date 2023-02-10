set -o errexit

stack install \
  --local-bin-path /usr/local/bin \
  weeder \
  fourmolu \
  ghcid \

rm -rf .stack-work /root/.stack
