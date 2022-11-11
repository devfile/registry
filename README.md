# registry

Devfile registry - storing contents of the public community, OCI-based, devfile registry hosted at <https://registry.devfile.io>.

The public registry is updated weekly, by 12pm EST Wednesdays, with any updated stacks in this repository.

## Registry Status

[![Validate Devfile stacks](https://github.com/devfile/registry/actions/workflows/validate-stacks.yaml/badge.svg?event=schedule)](https://github.com/devfile/registry/actions/workflows/validate-stacks.yaml)

## Registry Updates

The staging devfile registry, <https://registry.stage.devfile.io> is refreshed upon each commit to main in this repository. Production, <https://registry.devfile.io>, promoted manually and as mentioned above, is done each Wednesday, as needed.

If you are a stack owner and need to request an urgent refresh of <https://registry.devfile.io> before Wednesday (for example if a stack is broken), please open an issue in the [devfile/api](https://github.com/devfile/api) repository outlining the following:

- Stack name
- Why the refresh is needed
- Why the refresh cannot wait until the next regularly scheduled refresh
- `/area registry` somewhere in the issue description, so that the `area/registry` label gets added.

## Developing

### Prerequisites

- Docker 17.06 or later
- Git

### Build

To build this devfile registry into a container image run `.ci/build.sh`. A container image will be built using the [devfile registry build tools](https://github.com/devfile/registry-support/tree/master/build-tools).

From there, push the container image to a container registry of your choice and deploy using one of the methods outlined [here](https://github.com/devfile/registry-support#deploy).

## Contributing

For contributing Devfile stacks to this registry, please see [CONTRIBUTING.md](CONTRIBUTING.md).

## Telemetry

The Devfile Registry is configured with telemetry to collect only the necessary information to improve the value of our service.  For further details, refer to
the [Telemetry Data Collection Notice](TELEMETRY.md)

## Reporting any issue

For issues relating to a specific devfile stack in this repository, please reach out to the devfile stack maintainer to determine where to open an issue.

For issues relating to the hosted devfile registry service (<https://registry.devfile.io>), or devfile registries in general, please use the [devfile/api](https://github.com/devfile/api/) issue tracker for opening issues. Apply the `area/registry` label to registry issues for better visibility.
