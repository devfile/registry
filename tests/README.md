# Devfile Registry Testing

## Prerequisites

- Minikube installed, and running.
  - `minikube start --memory 8gb` is a good starting point.
  - The `none` driver **cannot** be used. Any other driver (`docker`, `hyperkit`, etc) should suffice.
- The ingress minikube addon **must** be installed with the `minikube addons enable ingress` command
- odo v2 or later.

## Running the tests

1) Ensure minikube is running and `minikube ip` reports a valid ip address

2) From the root of this repository, run `tests/test.sh`. 
  
    - The test script will validate each devfile stack under `stacks/` with odo, verifying that the stack can be used to build a starter project and that the application is properly built and exposed. 
       - The test script checks for an HTTP 200 status code to determine "properly exposed".
    - Each devfile stack **must** have at least one starter project specified in the devfile.yaml


## Limitations

- If there are multiple starter projects, odo will only use the first starter project mentioned.
- Only `odo create`,  `odo url create`, and `odo push` are tested right now. If your devfile stack exposes additional functionality (such as debug, via `odo debug`), we recommend either manually testing that functionality, or setting up your own test scripts in the stack's repository