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
./build-image.sh manifest
```

## Using an EC2 instances to build an ARM image:

You must have the `aws` cli install for this. First configure the project to
use your AWS account's EC2 instances by copying the example environment file
and filling in the environment variables:

```
cp ec2-build-machine.env.example ec2-build-machine.env
```

Then you can use

```
./ec2-build-machine.sh run
./ec2-build-machine.sh connect <instance-id>
./ec2-build-machine.sh terminate <instance-id>
```

To run an EC2 machine, build the image, and then terminate it. While connected
to the machine, you will need to run:

```
sudo yum install git docker
sudo systemctl start docker
sudo usermod -G docker ec2-user
newgrp docker
git clone https://github.com/flipstone/haskell-tools
cd haskell-tools
```

Once you have docker running and have cloned the repo to the EC2 instances you
can use the `build-image.sh` script as described above to build an ARM image.
