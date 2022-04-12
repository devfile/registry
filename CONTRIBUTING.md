# Contributing to this registry

This document outlines the requirements for contributing a devfile stack or sample to this repository.

The [devfile registry structure](https://github.com/devfile/api/blob/main/docs/proposals/registry/registry-structure.md#repository-structure) design doc provides some useful background information on the structure of resources in a devfile registry (and its Git repository).

## Prerequisites

The following are required to build the devfile index container image containing your stack or sample:

- Docker 17.06 or later
- Git

## Stacks

### Contributing

1) Verify your Devfile stack functions with odo.
  
    - Core odo functions such as `odo create --devfile <devfile.yaml>`, `odo push`, `odo url create` should work with the devfile.
    - PR tests on this repository will verify this functionality as well.

2) Verify your Devfile stack functions with Che.
  
    - Opening the URL `https://workspaces.openshift.com/#<devfile_url>` in your browser should start a workspace where `exec` commands run successfully. Type `task+<space>` in the IDE command palette to see the list of available commands.

3) Verify your Devfile stack has the following metadata fields at a minimum:

    - Name: The name of the devfile stack, e.g. `java-springboot`.
    - Display Name: The longer name of your devfile stack, e.g. `Spring Boot®`.
    - Description: A brief description of your devfile stack, e.g. `Spring Boot® using Java`.
    - Version: The version of your stack, in semnatic version format, e.g. `1.0.0`.

4) Add a folder for the stack to `stacks/` in this repository.
  
    - Make sure the name matches the devfile stack's name and be in the format `<language>-<framework>`. E.g. `java-quarkus`, `python-django`, etc.

5) Add the devfile.yaml and any other necessary files for the stack under the stack folder.

6) Run the `.ci/build.sh` to build the registry into a container image.
  
    - This will also validate the devfiles in this repository, making sure they conform to a minimum standard.
    - This step will also be run in the PR build for the repository.

7) Open a pull request against this repository with a brief description of the change.


### Updating

Updating an existing devfile stack is relatively straightforward:

1) Find the stack under the `stacks/` folder that you wish to update.
2) Make the necessary changes to the stack, such as: updating image tags, commands, starter projects, etc.
3) Update the version of stack, following the [semantic versioning format](https://semver.org/).
4) Test your changes:
    
    - Minimally, testing with odo (`odo create`, `odo push`, etc) is recommended, however if your Devfile is used with other tools, it's recommended to test there as well.
5) Open a pull request against this repository with your changes.

## Samples

### Contributing

The devfile samples used in this devfile registry are stored in the `extraDevfileEntries.yaml` file in the root of the repository. To add a devfile sample:

1) Verify your Sample functions with Che.
  
    - Opening the URL `https://workspaces.openshift.com/#<repository_url>` in your browser should start a workspace where `exec` commands run successfully. Type `task+<space>` in the IDE command palette to see the list of available commands.

2) Open `extraDevfileEntries.yaml` in an editor
3) Add an entry to the file with the following required fields:
```
  - name: <sample-name>
    displayName: <sample-display-name>
    description: <sample-description>
    icon: <link-to-sample-icon>
    tags: ["comma", "separated", "list", "of", "tags"]
    projectType: <sample-project-type>
    language: <sample-language>
    git:
      remotes:
        origin: <link-to-sample-git-repository>
```
4) Fill in the fields in the angle brackets based on your sample. Note that there must be only one git remote for the devfile sample. 
5) Open a pull request against this repository with your changes.

### Updating

To update a sample:

1) Open `extraDevfileEntries.yaml` in an editor.
2) Find the entry for the sample you wish to update.
3) Make the necessary changes.
4) Open a pull request against this repository with your changes.


## How to Test Changes

### Odo
`odo create` and `odo push` to test devfile changes. See [Odo Doc](https://odo.dev/docs/using-odo/create-component) for more details.

### Che
Opening the URL `https://workspaces.openshift.com/#<repository_url>` in your browser should start a workspace where `exec` commands run successfully. Type `task+<space>` in the IDE command palette to see the list of available commands.

### Console
In developer view, create an application via `Import from Git`. Provide git repository Url and verify if the application can be built and ran successfully. 
Note: Currently Console only works with devfile v2.2.0 samples with outer loop support. 
