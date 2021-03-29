# Contributing a Devfile Stack to this registry

This document outlines the requirements for contributing a devfile stack to this repository

## Steps

1) Verify your Devfile stack functions with odo.
  
    - Core odo functions such as `odo create --devfile <devfile.yaml>`, `odo push`, `odo url create` should work with the devfile.
    - CI tests on this repository will verify this functionality as well.

2) Add a folder for the stack to `stacks/` in this repository.
  
    - Name format should be in the form of `<language>-<framework>`. E.g. `java-quarkus`, `python-django`, etc.

3) Add the devfile.yaml and 

4) Run the `.ci/build.sh` to build the registry into a container image.
  
    - This will also validate the devfiles in this repository, making sure they conform to a minimum standard.
    - This step will also be run in the CI build for the repository.

5) (Optional) Push the container image to a container registry and [deploy](https://github.com/devfile/registry-support#deploy) on to Kubernetes or OpenShift.
  
    - For now, strictly an optional requirement, but recommended.

6) Open a pull request against this repository.