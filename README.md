# registry
Devfile registry - storing contents of the common devfile registry that feeds into the OCI based common registry.

The devfiles in this repository feed into the publicly hosted devfile registry at https://registry.devfile.io. 

## Build

To build this devfile registry into a container image:

1. git clone `github.com/devfile/registry-support`
2. cd into `registry-support/build-tools`
3. Run `build.sh <path-to-this-repository-on-disk>`

From there, push the container image to a container registry of your choice and deploy using one of the methods outlined [here](https://github.com/devfile/registry-support#deploy).

## Reporting any issue

For issues relating to a specific devfile stack in this repository, please reach out to the devfile stack maintainer to determine where to open an issue.

For issues relating to the hosted devfile registry service (https://registry.devfile.io), or devfile registries in general, please use the [devfile/api](https://github.com/devfile/api/) issue tracker for opening issues. Apply the `area/registry` label to registry issues for better visibility.
