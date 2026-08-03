# Haskell Tools

This repository has a workflow defined that will build and push amd64 and arm64
images to Github Container Registry.

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

# How to build this for release

Once you push to Github (either on a branch or main), the Github workflow
will build a multi-architecture version of the image and publish it to the
Github Container Registry. From there it can be used as a base for other 
images or directly in projects that require no further tools to be installed.

# For Flipstone Developers

Update all our repositories that use this image, to the latest, when
a new image is published. This list can be found in the codex.
