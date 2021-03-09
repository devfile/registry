# registry
Devfile registry - storing contents of the common devfile registry that feeds into the OCI based common registry

## Build

To build this devfile registry into a container image:

1. git clone `github.com/devfile/registry-support`
2. cd into `registry-support/build-tools`
3. Run `build.sh <path-to-this-repository-on-disk>`

From there, push the container image to a container registry of your choice.
