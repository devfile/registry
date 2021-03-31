# Contributing a Devfile Stack to this registry

This document outlines the requirements for contributing a devfile stack to this repository

The [devfile registry structure](https://github.com/devfile/api/blob/main/docs/proposals/registry/registry-structure.md#repository-structure) design doc provides some useful background information on the structure of resources in a devfile registry (and its Git repository).

## Prerequisites

The following are required to build the devfile index container image containing your stack:

- Golang 1.13.x or later
- Docker 17.06 or later
- Git

## Steps

1) Verify your Devfile stack functions with odo.
  
    - Core odo functions such as `odo create --devfile <devfile.yaml>`, `odo push`, `odo url create` should work with the devfile.
    - PR tests on this repository will verify this functionality as well.

2) Add a folder for the stack to `stacks/` in this repository.
  
    - Name format should be in the form of `<language>-<framework>`. E.g. `java-quarkus`, `python-django`, etc.

3) Add the devfile.yaml and any other necessary files for the stack under the stack folder.

4) Run the `.ci/build.sh` to build the registry into a container image.
  
    - This will also validate the devfiles in this repository, making sure they conform to a minimum standard.
    - This step will also be run in the PR build for the repository.

5) (Optional) Push the container image to a container registry and [deploy](https://github.com/devfile/registry-support#deploy) a custom devfile registry on to Kubernetes or OpenShift. Test odo with the devfile stack hosted in that registry.
  
    - For now, strictly an optional requirement, but recommended.
    - PR tests will also verify this.

6) Open a pull request against this repository with a brief description of the change.