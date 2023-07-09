# Haskell Tools

This repository has a workflow defined that will build and push amd64 and arm64
images to Github Container Registry.

# For Flipstone Developers
* Update all our repositories that use this image, to the latest, when
a new image is published. This list can be found in the codex.


# How to build this using docker

* Use `./build-image.sh push-arch-tag` on your machine to build a local image
  for testing. As you make changes locally the images will be tagged with
  `-uncommitted` on the end rather than the commit SHA.

* Update the base tag in `./build-image.sh` as necessary to reflect changes
  in the base image or GHC version included in the image.

* On an AMD64 machine:

```
./build-image.sh build-arch-tag
./build-image.sh push-arch-tag
```

* On an ARM64 machine:

```
./build-image.sh build-arch-tag
./build-image.sh push-arch-tag
```

* On either machine:

```
./build-image.sh push-manifest
```

