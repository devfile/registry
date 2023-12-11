# registry

Devfile registry - storing contents of the public community, OCI-based, devfile registry hosted at <https://registry.devfile.io>.

The public registry is updated weekly, by 12pm EST Wednesdays, with any updated stacks in this repository.

## Registry Status

[![Validate Devfile stacks](https://github.com/devfile/registry/actions/workflows/validate-stacks.yaml/badge.svg?event=schedule)](https://github.com/devfile/registry/actions/workflows/validate-stacks.yaml)
[![Renovate][1]][2]

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

To build this devfile registry into a container image run `bash .ci/build.sh`. A container image will be built using the [devfile registry build tools](https://github.com/devfile/registry-support/tree/master/build-tools). By default these scripts will use `docker`, if you want to use `podman` you should first run `export USE_PODMAN=true` before executing the build script.

From there, push the container image to a container registry of your choice and deploy using a [devfile adopted devtool](https://devfile.io/docs/2.2.0/developing-with-devfiles#tools-that-provide-devfile-support) or one of the methods outlined [here](https://github.com/devfile/registry-support#deploy).

## Devfile Deployments

### Prerequisites

- Docker 17.06 or later
- Git
- Kubernetes or Red Hat OpenShift
- odo v3.15.0+

### Deploying

The following can be used to build and deploy a devfile registry locally:

odo V3: 

```sh
odo deploy --var indexImageName=quay.io/<user>/devfile-index --var indexImageTag=<tag>
```

`odo deploy` needs these overrides to not push to the default `quay.io/devfile/devfile-index:next`.

Prevent odo v3 deployment built images from being pushed by running:

```sh
# Set docker to target minikube's image registry
eval $(minikube docker-env)

ODO_PUSH_IMAGES=false odo deploy --var indexPullPolicy=Never
```

### Removing Deployments

Deployments made locally can be deleted using:

odo V3: `odo delete component --name devfile-registry-community`

## Contributing

For contributing Devfile stacks to this registry, please see [CONTRIBUTING.md](CONTRIBUTING.md).

## Telemetry

The Devfile Registry is configured with telemetry to collect only the necessary information to improve the value of our service.  For further details, refer to
the [Telemetry Data Collection Notice](TELEMETRY.md)

## Reporting any issue

For issues relating to a specific devfile stack in this repository, please reach out to the devfile stack maintainer to determine where to open an issue.

For issues relating to the hosted devfile registry service (<https://registry.devfile.io>), or devfile registries in general, please use the [devfile/api](https://github.com/devfile/api/) issue tracker for opening issues. Apply the `area/registry` label to registry issues for better visibility.

[1]: https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovate
[2]: https://renovatebot.com
