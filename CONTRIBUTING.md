# Contributing

This document outlines the requirements for contributing a devfile stack or sample to this repository.

The [devfile registry structure](https://github.com/devfile/api/blob/main/docs/proposals/registry/registry-structure.md#repository-structure) design doc provides some useful background information on the structure of resources in a devfile registry (and its Git repository).

When onboarding a new stack or sample, the  `Stack Provider` should read and agree to follow their roles and responsibilities outlined in the [Lifecycle](LIFECYCLE.md) doc.

## Code of Conduct

Before contributing to this repository for the first time, please review our project's [Code of Conduct](https://github.com/devfile/api/blob/main/CODE_OF_CONDUCT.md).

## Certificate of Origin

By contributing to this project you agree to the Developer Certificate of
Origin (DCO). This document was created by the Linux Kernel community and is a
simple statement that you, as a contributor, have the legal right to make the
contribution. See the [DCO](DCO) file for details.

In order to show your agreement with the DCO you should include at the end of the commit message,
the following line:

```console
Signed-off-by: Firstname Lastname <email@email.com>
```

Once you set your user.name and user.email in your git config, you can sign your commit automatically with `git commit -s`.

## How to Contribute:

### Issues

For issues relating to a specific devfile stack in this repository, please reach out to the devfile stack maintainer to determine where to open an issue.

For issues relating to the hosted devfile registry service (<https://registry.devfile.io>), or devfile registries in general, please use the [devfile/api](https://github.com/devfile/api/issues) issue tracker for opening issues. Apply the `area/registry` label to registry issues for better visibility.

### Submitting Pull Request

When you think the code is ready for review, create a pull request and link the issue associated with it.

Owners of the repository will watch out for new PRs and provide reviews to them.

If comments have been given in a review, they have to be addressed before merging.

After addressing review comments, don't forget to add a comment in the PR with the reviewer mentioned afterward, so they get notified by Github to provide a re-review.

See [Registry Stack Review Process](#registry-stack-review-process) for more information about the review process of devfile registry content.

### Prerequisites

The following are required to build the devfile index container image containing your stack or sample:

- Docker or Podman
- Git

### Instructions for new registry entries

1. Open an [issue](#issues) to track adding a new stack or sample
2. Avoid using container images (check for references in the Devfile and Dockerfile) from registries (like DockerHub) that impose rate limiting.  To workaround this, you can mirror the images to quay.io by using a similar approach to what the Devfile team has: https://github.com/devfile-samples/image-mirror/

### Stacks

#### Contributing

1) Verify your Devfile stack functions with odo.

    - Core odo v2 functions such as `odo create --devfile <devfile.yaml>`, `odo push`, `odo url create` should work with the devfile.
    - Core odo v3 functions such as `odo init`, `odo dev`, `odo deploy` should work with the devfile.
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

5) In case one of your components has a reference to an image, use a fixed version tag (e.g `<image>:1.1.0`) instead of `latest`. Our renovate bot will take care of the updates to the image tags.

6) Add the devfile.yaml and any other necessary files for the stack under the stack folder.

7) Run the `.ci/build.sh` to build the registry into a container image.

    - This will also validate the devfiles in this repository, making sure they conform to a minimum standard.
    - This step will also be run in the PR build for the repository.
    - Run `.ci/build.sh offline` to package online resources into
    the image for offline / air gap environments.

8) Open a pull request against this repository with a brief description of the change.

#### Updating

Updating an existing devfile stack is relatively straightforward:

1) Find the stack under the `stacks/` folder that you wish to update.
2) Make the necessary changes to the stack, such as: updating image tags, commands, starter projects, etc.
3) Update the version of stack, following the [semantic versioning format](https://semver.org/).

    - When updating a stack with a newer version of the devfile specification (e.g., 2.1.0 -> 2.2.0), the previous version of the stack **must** be kept for a minimum of one (1) year.
4) Test your changes:

    - Minimally, testing with odo v2 (`odo create`, `odo push`, etc), odo v3 (`odo init`, `odo dev`, etc) and che (see [How to Test Changes > Che](https://github.com/devfile/registry/blob/main/CONTRIBUTING.md#che)) is recommended, however if your Devfile is used with other tools, it's recommended to test there as well.
5) Open a pull request against this repository with your changes.

#### Automatic Stack Image Update

As images used inside the stacks need to be up-to-date and in order to avoid using the `latest` tag, the renovate bot runs periodically ensuring that all images used from stacks (for example, inside components) have the latest version. As a result, all images used inside a devfile of a stack need to have a fixed version (e.g `1.1.0`) instead of `latest`.

### Registry Stack Review Process

For every PR, containing updates for registry stacks the review process is: 

* All [CODEOWNERS](./.github/CODEOWNERS) related with the stack are requested to provide their review.
* The PR should be first approved from the stack owner & one eclipse che team member.
* A devfile-services team member should confirm that the PR has the required reviews and if yes, merge it.

For more informations about stack owners please take a look at the [CODEOWNERS](./.github/CODEOWNERS) file.

### Samples

#### Contributing

The devfile samples used in this devfile registry are stored in the `extraDevfileEntries.yaml` file in the root of the repository. To add a devfile sample:

1) Verifying your Sample functions with OpenShift Console

    - Use the Developer perspective and import the Devfile Sample using Import from Git.

2) Verifying your Sample functions with Konflux

    - Create an application by importing the sample from Git.

3) Open `extraDevfileEntries.yaml` in an editor
4) Add an entry to the file with the following required fields:

    ```yaml
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

5) Fill in the fields in the angle brackets based on your sample. Note that there must be only one git remote for the devfile sample.
6) Open a pull request against this repository with your changes.

#### Adding a new version

In case you want to add another version to a new devfile sample you can update the existing sample inside the `extraDevfileEntries.yaml` file:

1) Verifying your Sample functions with OpenShift Console

    - Use the Developer perspective and import the Devfile Sample using Import from Git.

2) Verifying your Sample functions with Konflux

    - Create an application by importing the sample from Git.

3) Open `extraDevfileEntries.yaml` in an editor
4) A sample with multiple versions should be:

    ```yaml
    - name: <sample-name>
        displayName: <sample-display-name>
        description: <sample-description>
        icon: <link-to-sample-icon>
        tags: ["comma", "separated", "list", "of", "tags"]
        projectType: <sample-project-type>
        language: <sample-language>
        versions:
        - version: <version1>
            schemaVersion: <devfile-schemaVersion>
            git:
            checkoutFrom:
                revision: <sample-git-repo-commit-id-or-branch>
            remotes:
                origin: <link-to-sample-git-repository>
        - version: <version1>
            schemaVersion: <devfile-schemaVersion>
            git:
            checkoutFrom:
                revision: <sample-git-repo-commit-id-or-branch>
            remotes:
                # Note that it is also possible to use different repos
                # for each version of a sample.
                origin: <link-to-sample-git-repository>
    ```

5) Fill in the fields in the angle brackets based on your sample. Note that there must be only one git remote for the devfile sample.
6) Open a pull request against this repository with your changes.

#### Updating

To update a sample:

1) Open `extraDevfileEntries.yaml` in an editor.
2) Find the entry for the sample you wish to update.
3) Make the necessary changes.
4) Open a pull request against this repository with your changes.

### How to Test Changes

#### Odo

odo v2: `odo create` and `odo push` to test devfile changes. See [odo v2 Doc](https://odo.dev/docs/2.5.0/using-odo/create-component) for more details.

odo V3: `odo init` and `odo dev` to test devfile changes. See [odo v3 Doc](https://odo.dev/docs/command-reference/init) for more details.

#### Che

Opening the URL https://workspaces.openshift.com/#<repository_url> in your browser should start a workspace where exec commands run successfully. Type `task devfile` and press the `Enter` key in the IDE command palette to see the list of available devfile commands. Then, run all devfile commands one by one, to ensure they are executed successfully.

#### Console

In developer view, create an application via `Import from Git`. Provide git repository Url and verify if the application can be built and ran successfully.
Note: Currently Console only works with devfile v2.2.0 samples with outer loop support.

# Contact us

If you have any questions, please visit us the `#devfile` channel under the [Kubernetes Slack](https://slack.k8s.io) workspace.
