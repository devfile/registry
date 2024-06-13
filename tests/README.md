# Devfile Registry Testing

## Dependency check

### Prerequisites

- Ensure [yq 4.x](https://github.com/mikefarah/yq/#install) is installed

### Running the build script

- This script performs three actions
  - Clones samples from provided `extraDevfileEntries.yaml` under `samples/.cache`
  - Creates a `parents.yaml` which contains the dependency tree for parent stacks
  - Outputs the child sample paths of parent stacks, `TEST_DELTA=true` will result in only outputting child samples which have changed parent stacks
- The build script takes one optional argument and works off of the current working directory
  - `bash tests/build_parents_file.sh`, default samples file is `extraDevfileEntries.yaml`
  - `bash tests/build_parents_file.sh <path_to_extraDevfileEntries>`

### Use with testing

- One can test the child samples using the [validate_devfile_schemas](./validate_devfile_schemas/) test suite by performing the following:
```sh
export STACKS=$(bash tests/build_parents_file.sh)
STACKS_DIR=.cache/samples bash tests/validate_devfile_schemas.sh --samples
```

## Validating non-terminating images

### Prerequisites

- Minikube installed, and running.
  - `minikube start --memory 8gb` is a good starting point.
  - The `none` driver **cannot** be used. Any other driver (`docker`, `hyperkit`, etc) should suffice.

### Running the tests

1) From the root of this repository, run `bash tests/check_non_terminating.sh`.
    - The test script will validate each devfile stack under `stacks/`, verifying that the components of type container are terminating. 
       - The test script retrieves the `image`, `command` and `args` of a container component and uses them to run a pod and wait until it reaches the `Running` state:
          ```bash
          kubectl run test-terminating -n default --attach=false --restart=Never --image="<image>" --command=true -- "<command>" "<args>"
          ```
    - Each container component **must** be non-terminating. If the default `image` entrypoint is terminating an `args` (preferred) or `command` should be specified in the defile (e.g. `["tail", "-f", "/dev/null"]`).


## With odo v3

### Prerequisites

- Minikube or CRC installed, and running.
  - CRC should work with default settings.
  - Minikube
    - `minikube start --memory 8gb` is a good starting point.
    - The `none` driver **cannot** be used. Any other driver (`docker`, `hyperkit`, etc) should suffice.
- odo v3.0.0-rc2 or later.
- Go 1.21 or later installed
  - `$GOPATH/bin` should be in your `$PATH` or you will have to modify `check_with_odov3.sh` to find `ginkgo` binary.
- Ginkgo CLI installed (`go install github.com/onsi/ginkgo/v2/ginkgo@latest`)


### Running the tests

1) Ensure minikube is running and `minikube ip` reports a valid IP address
2) From the root of this repository, run `bash tests/check_odov3.sh`.
    - The test script will validate that every devfile under `stacks` directory works with all the starter projects defined in a given stack.

### Limitations

- Currently, the test expects that all starter projects are web applications that return `HTTP 200` status code on the root path (`/`).

## With odo v2

### Prerequisites

- Minikube installed, and running.
  - `minikube start --memory 8gb` is a good starting point.
  - The `none` driver **cannot** be used. Any other driver (`docker`, `hyperkit`, etc) should suffice.
- The ingress minikube addon **must** be installed with the `minikube addons enable ingress` command
- latest odo v2 (currently 2.5.1)

### Running the tests

1) Ensure minikube is running and `minikube ip` reports a valid ip address

2) From the root of this repository, run `bash tests/check_odov2.sh`.
  
    - The test script will validate each devfile stack under `stacks/` with odo, verifying that the stack can be used to build a starter project and that the application is properly built and exposed.
       - The test script checks for an HTTP 200 status code to determine "properly exposed".
    - Each devfile stack **must** have at least one starter project specified in the devfile.yaml

### Limitations

- If there are multiple starter projects, odo will only use the first starter project mentioned.
- Only `odo create`,  `odo url create`, and `odo push` are tested right now. If your devfile stack exposes additional functionality (such as debug, via `odo debug`), we recommend either manually testing that functionality, or setting up your own test scripts in the stack's repository