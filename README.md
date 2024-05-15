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

# How to build this for release

Once you push to Github (either on a branch or main), the Github workflow
will build a multi-architecture version of the image and publish it to the
Github Container Registry. From there it can be used as a base for other 
images or directly in projects that require no further tools to be installed.
