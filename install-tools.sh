set -o errexit

stack install \
  --local-bin-path /root/.local/bin \
  weeder \
  fourmolu \
  ghcid \

rm -rf .stack-work /root/.stack
