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

cabal update

# These are done as separate install commands so that the tools
# are not forced to use the exact same dependencies, which cabal
# might not be able to satisfy for all of them at once.
# We use cabal rather than stack to install these so that they
# can be versioned separately from the lts we're using --
# especially if they version we want of a tool cannot compile
# with our lts. Since these tools are all binary executables
# copied into the final image they don't need to share all same
# dependency versions with each other or the lts.
cabal install --installdir=install-tools-bins weeder-$WEEDER_VERSION
cabal install --installdir=install-tools-bins fourmolu-$FOURMOLU_VERSION
cabal install --installdir=install-tools-bins ghcid-$GHCID_VERSION
cabal install --installdir=install-tools-bins hlint-$HLINT_VERSION
cabal install --installdir=install-tools-bins ShellCheck-$SHELLCHECK_VERSION
cabal install --installdir=install-tools-bins stan-$STAN_VERSION
