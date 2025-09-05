set -o errexit

mkdir /install-tools-bins

arch=$(uname -m)
if [ "$arch" = x86_64 ]; then
  curl --fail -Lo /install-tools-bins/ghciwatch "https://github.com/MercuryTechnologies/ghciwatch/releases/download/v${GHCIWATCH_VERSION}/ghciwatch-x86_64-linux"
elif [ "$arch" = aarch64 ]; then
  curl --fail -Lo /install-tools-bins/ghciwatch "https://github.com/MercuryTechnologies/ghciwatch/releases/download/v${GHCIWATCH_VERSION}/ghciwatch-aarch64-linux"
else
  echo "install-tools.sh: Unknown architecture $arch"
  exit 1
fi

chmod +x /install-tools-bins/ghciwatch

stack install \
  --local-bin-path /install-tools-bins \
  weeder \
  fourmolu \
  ghcid \
  hlint \
  ShellCheck \
  stan
