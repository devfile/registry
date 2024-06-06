# registry

TEST 

Devfile registry - storing contents of the public community, OCI-based, devfile registry hosted at <https://registry.devfile.io>.

The public registry is updated weekly, by 12pm EST Wednesdays, with any updated stacks in this repository.

## Registry Status

![Go](https://img.shields.io/badge/Go-1.19-blue)
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

If you are trying to run `bash .ci/build_and_deploy.sh` and are experiencing errors while using MacOS with an apple silicon chip, you should first run `export PLATFORM_EV=linux/arm64` to properly set the container config. By default the containers will be built for `linux/amd64`.

## Devfile Deployments

### Prerequisites

- Docker 17.06 or later
- Git
- Kubernetes or Red Hat OpenShift
- odo v3.15.0+

### Deploying

#### odo V3

The following can build and deploy a devfile registry using odo v3:

```sh
odo deploy --var indexImageName=quay.io/<user>/devfile-index --var indexImageTag=<tag>
```

**Important**: `odo deploy` needs these overrides to not push to the default `quay.io/devfile/devfile-index:next`.

The deployment host name can be set by overriding `hostName` and `hostAlias`:

```sh
odo deploy --var hostName=devfile-registry.<cluster_hostname> \
    --var hostAlias=devfile-registry.<cluster_hostname> \
    --var indexImageName=quay.io/<user>/devfile-index \
    --var indexImageTag=<tag>
```

**Notes**: 
- `hostName` is required for Kubernetes ingresses, OpenShift routes are optional and defaults to `<deployment_namespace>.<cluster_hostname>`.
- `hostAlias` sets the leading host name under static links in registry viewer entries, defaults to our staging deployment `registry.stage.devfile.io`.

Prevent odo v3 deployment built images from being pushed by running:

```sh
# Set docker to target minikube's image registry
eval $(minikube docker-env)

ODO_PUSH_IMAGES=false odo deploy \
    --var hostName=devfile-registry.<cluster_hostname> \
    --var hostAlias=devfile-registry.<cluster_hostname> \
    --var indexPullPolicy=Never
```

### Removing Deployments

#### odo V3

Deployments made with odo v3 can be deleted using:

```sh
odo delete component --name devfile-registry-community
```

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

## Code of Conduct

Please reference our [Code of Conduct](https://github.com/devfile/api/blob/e37cd6b0b4ac21524a724e68373746393b91b9ed/CODE_OF_CONDUCT.md) for more information.

## Governance

Please reference [GOVERNANCE.md](https://github.com/devfile/api/blob/e37cd6b0b4ac21524a724e68373746393b91b9ed/GOVERNANCE.md) for more information.

## Users

A list of users that use this project can be found by referencing [USERS.md](USERS.md)

## Meetings

Information regarding meetings for the Devfile project can be found in [GOVERNANCE.md](https://github.com/devfile/api/blob/e37cd6b0b4ac21524a724e68373746393b91b9ed/GOVERNANCE.md#meetings)

## Slack

There is a Slack channel open for discussion under the Kubernetes Slack workspace, you can find it [here](https://kubernetes.slack.com/messages/devfile)
