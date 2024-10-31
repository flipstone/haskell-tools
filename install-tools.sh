set -o errexit

arch=$(uname -m)
if [ "$arch" = x86_64 ]; then
  curl -Lo /usr/local/bin/ghciwatch "https://github.com/MercuryTechnologies/ghciwatch/releases/download/v1.0.1/ghciwatch-x86_64-linux"
elif [ "$arch" = aarch64 ]; then
  curl -Lo /usr/local/bin/ghciwatch "https://github.com/MercuryTechnologies/ghciwatch/releases/download/v1.0.1/ghciwatch-aarch64-linux"
else
  echo "install-tools.sh: Unknown architecture $arch"
  exit 1
fi
chmod +x /usr/local/bin/ghciwatch

stack install \
  --local-bin-path /usr/local/bin \
  weeder \
  fourmolu \
  ghcid \
  hlint \
  ShellCheck

rm -rf .stack-work /root/.stack
