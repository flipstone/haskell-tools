# Haskell Tools

This repository has a workflow defined that will build and push amd64 and arm64
images to GitHub Container Registry.

Repository layout:

- `Dockerfile` and `image/` — the tooling image definition and the files
  copied into it
- `scripts/` — scripts run on the host (`bootstrap.sh`, `build-image.sh`)
- `compose.yaml` — containerized dev tooling (trivy, shellcheck, hadolint),
  so nothing needs to be installed on the host
- `tool-versions.env` — single source of truth for the tool versions baked
  into the image

# Getting started

After cloning, run `./scripts/bootstrap.sh` once. It detects where your
Docker daemon socket lives (e.g. rootless Docker keeps it under
`/run/user/...`) and records it as `DOCKER_SOCK` in a local `.env` file,
which docker compose reads automatically.

Building the image locally also requires a one-time `docker login dhi.io`
(your Docker Hub credentials work). The base image is Docker Hardened
Images' `debian-base` (free Community tier), which requires authentication
to pull. Its tag is rolling, so the Dockerfile pins it by digest and
dependabot bumps the digest monthly.

# How to build this using docker to test locally

Run `./scripts/build-image.sh build-local-beta` to build a local image tagged as
`haskell-tools-beta`. You can then use that image locally to test on other
repos before building an official image.

# How to scan images for vulnerabilities

Run `./scripts/build-image.sh scan-local-beta` to scan a locally built beta
image with [Trivy](https://trivy.dev), or `docker compose run --rm trivy image
IMAGE` to scan any other image reference. Trivy runs from its official Docker
image via the `trivy` service in `compose.yaml`, so no host install is
required. Scanning locally built images relies on the `DOCKER_SOCK` value that
`./scripts/bootstrap.sh` writes to `.env`.

Scan behaviour is controlled with environment variables, with defaults set in
`compose.yaml`: `TRIVY_SEVERITY` (default `HIGH,CRITICAL`), `TRIVY_EXIT_CODE`
(default `0`, report only; `1` fails on findings), and `TRIVY_IGNORE_UNFIXED`
(default `true`, so reports only contain findings that have a released fix
and are therefore actionable; set to `false` to see everything).

The `scan-local-beta` and `scan-amd64-tag` commands also write each report to
the (gitignored) `trivy-reports/` directory.

The CI workflow runs the same scan against the amd64 image before the
multi-architecture manifest is pushed. The results appear in the job summary
on the workflow run page and are uploaded as a downloadable `trivy-reports`
artifact. The scan is
report-only; set `TRIVY_EXIT_CODE: '1'` on the workflow's scan step to make
HIGH/CRITICAL findings block publication of the manifest tag.

# How to lint this repository

CI lints the shell scripts and the Dockerfile on every push. To run the same
checks locally:

```
docker compose run --rm shellcheck scripts/*.sh image/*.sh
docker compose run --rm hadolint hadolint Dockerfile
```

Hadolint configuration (ignored rules) lives in `.hadolint.yaml`.

# Dependabot

Dependabot bumps the base image digest and the GitHub Actions versions
monthly. CI runs on Dependabot branches verify that both arch images still
build (using the registry layer cache) but publish nothing: the image push,
scan, and manifest steps are skipped.

Workflows triggered by Dependabot read secrets from the separate
Dependabot secrets store (repo Settings > Secrets and variables >
Dependabot), so `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` must be
configured there as well as in Actions secrets — otherwise the Docker Hub
and dhi.io logins fail on every Dependabot PR. The same two secrets also
let Dependabot authenticate to dhi.io for base image digest updates (see
`.github/dependabot.yaml`).

# Image tags and releases

Once you push to GitHub (either on a branch or main), the GitHub workflow
will build a multi-architecture version of the image and publish it to the
GitHub Container Registry. From there it can be used as a base for other
images or directly in projects that require no further tools to be installed.

The registry holds three kinds of tags:

- `debian-ghc-X.Y.Z-<sha7>` — per-commit tags, published for every push on
  every branch. Use these to try out a not-yet-merged image.
- `debian-ghc-X.Y.Z-build-YYYY.M.D.N` — release tags, minted automatically
  from main whenever a push changed the image or how it is built
  (`Dockerfile`, `tool-versions.env`, `image/`, or
  `scripts/build-image.sh`). Docs- and CI-only merges don't mint one.
  These are the tags downstream repositories should pin. The date is the
  commit date and `N` is the workflow run number; month and day are
  unpadded (`2026.8.6`, not `2026.08.06`) because Dependabot compares
  version segments numerically.
- `buildcache-*` — registry-hosted layer caches, internal to CI; never pin
  these.

A release tag is a digest-identical re-tag of the same commit's sha
manifest, created after the Trivy scan (so a blocking scan configuration
also blocks releases). The tag is derived from the commit date and run
number, so re-running a main workflow recreates the same tag rather than
minting a new one.

To try a candidate image downstream before merging: push your haskell-tools
branch, pin the resulting `debian-ghc-X.Y.Z-<sha7>` tag on a branch of the
downstream repository, and iterate. Once your change merges here, Dependabot
opens the release-tag bump PR in each downstream repository — discard the
sha-tag test pin rather than merging it.

# For Flipstone Developers

Repositories that use this image should pin a release tag
(`debian-ghc-X.Y.Z-build-YYYY.M.D.N`) and carry a `.github/dependabot.yml`
so new releases arrive as bump PRs automatically:

```yaml
version: 2
updates:
  - package-ecosystem: "docker-compose" # image: lines in compose files
    directory: "/"
    schedule:
      interval: "weekly"
  - package-ecosystem: "docker" # FROM lines in Dockerfiles
    directory: "/"
    schedule:
      interval: "weekly"
```

Dependabot keeps `tag@sha256:...` pins working too — it updates the tag and
digest together. It only proposes updates within the currently pinned GHC
version: the GHC version sits in the part of the tag Dependabot treats as an
opaque prefix, so a GHC upgrade is a deliberate, one-time manual pin edit in
each downstream repository, made alongside the code and resolver changes the
upgrade requires anyway. The list of repositories using this image can be
found in the codex.
