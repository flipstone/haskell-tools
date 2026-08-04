# Haskell Tools

This repository has a workflow defined that will build and push amd64 and arm64
images to Github Container Registry.

# For Flipstone Developers

Update all our repositories that use this image, to the latest, when
a new image is published. This list can be found in the codex.

# How to build this using docker to test locally

Run `./build-image.sh build-local-beta` to build a local image tagged as
`haskell-tools-beta`. You can then use that image locally to test on other
repos before building an official image.

# How to scan images for vulnerabilities

Run `./build-image.sh scan-local-beta` to scan a locally built beta image with
[Trivy](https://trivy.dev), or `./trivy-scan.sh IMAGE` to scan any other image
reference. The script uses a locally installed `trivy` when available and
falls back to the official Trivy Docker image otherwise, so no host install is
required. See `./trivy-scan.sh --help` for the environment variables that
control severity and failure behaviour.

The CI workflow runs the same script against the amd64 and arm64 images before
the multi-architecture manifest is pushed. The scan is report-only; set
`TRIVY_EXIT_CODE: '1'` on the workflow's scan step to make HIGH/CRITICAL
findings block publication of the manifest tag.

# How to build this for release

Once you push to Github (either on a branch or main), the Github workflow
will build a multi-architecture version of the image and publish it to the
Github Container Registry. From there it can be used as a base for other 
images or directly in projects that require no further tools to be installed.
