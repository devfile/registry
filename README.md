# registry

Devfile registry - storing contents of the public community, OCI-based, devfile registry hosted at <https://registry.devfile.io>.

The public registry is updated weekly, by 12pm EST Wednesdays, with any updated stacks in this repository.

## Registry Status

![Go](https://img.shields.io/badge/Go-1.21-blue)
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

- Docker or Podman
- Git

### Build

To build this devfile registry into a container image run `bash .ci/build.sh`. A container image will be built using the [devfile registry build tools](https://github.com/devfile/registry-support/tree/master/build-tools). By default these scripts will use `docker` and be built for the `linux/amd64` architecture. 

To build using `podman` first run:
```
export USE_PODMAN=true
```
To build for `linux/arm64` run:
```
bash .ci/build.sh linux/arm64
```

From there, push the container image to a container registry of your choice and deploy using a [devfile adopted devtool](https://devfile.io/docs/2.2.0/developing-with-devfiles#tools-that-provide-devfile-support) or one of the methods outlined [here](https://github.com/devfile/registry-support#deploy).

If you are trying to run `bash .ci/build_and_deploy.sh` and are experiencing errors while using MacOS with an apple silicon chip, you should first run `export PLATFORM_EV=linux/arm64` to properly set the container config. By default the containers will be built for `linux/amd64`.

## Devfile Deployments

### Prerequisites

- Docker or Podman
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

## Governance

Please reference [GOVERNANCE.md](https://github.com/devfile/api/blob/main/GOVERNANCE.md) for more information.

## Users

A list of users that use this project can be found by referencing [USERS.md](USERS.md)

## Meetings

Information regarding meetings for the Devfile project can be found in [GOVERNANCE.md](https://github.com/devfile/api/blob/main/GOVERNANCE.md#meetings)

## Slack

There is a Slack channel open for discussion under the Kubernetes Slack workspace, you can find it [here](https://kubernetes.slack.com/messages/devfile)

[1]: https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovate
[2]: https://renovatebot.com
