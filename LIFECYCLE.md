# Lifecycle Maintenance of Devfile Registry Stacks

The purpose of this document is to clarify the roles and responsibilities for maintaining the devfile stacks and samples present in the [devfile Community registry](https://github.com/devfile/registry).
Devfiles are intended to be used by developers to build their applications with tooling clients that support the devfile spec. As a result, it’s important that stack providers avoid introducing breaking changes or allowing security vulnerabilities to go unremediated which would result in a degradation of our end users applications.  In short, we need to ensure our devfiles are trusted enough to be used. In order to achieve this, there is a level of shared responsibility in all of the roles defined below.


| Role                    | Description                                                                                                                             |
|:------------------------|:----------------------------------------------------------------------------------------------------------------------------------------|
| `Devfile Team`          | The team that is responsible for onboarding vendor devfiles for the community registry.                              |
| `Stack/Sample Provider` | The person or team that is responsible for developing the devfile stack or sample that is available for sharing on our devfile registry. |
| `Tooling Clients`       | These are the tools that support building devfile-based applications                                                                    |
| `End Users`             | Application developers that consume devfiles for the purpose of building their own custom applications                                  |

The following sections describe the steps that can happen in the lifecycle of a devfile.

## [Onboarding](CONTRIBUTING.md)
When a `Stack Provider` is ready to share their devfile to the public registry, they must follow the steps in the [contributing guide](CONTRIBUTING.md) to ensure there’s basic information that identifies the version, owner, description, etc. of the stack or sample. They must also ensure the stack or sample meets minimal testing requirements against the supported clients.

| Role             | Responsibilities                                                                                                                                                                                                                                                                                                           |
|:-----------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Stack Provider` | <ul>Follow the [contributing guide](CONTRIBUTING.md) and ensure stack or sample is tested against the supported clients </ul>                                                                                                                                                                                                        |
| `Devfile Team`   | <ul><li>Review the PR</li><li>Work with `Tooling Clients` to ensure there is sufficient testing</li><li>Ensure the stack has the right contact information, any 2.2.x and above versions contain the support link</li><li>Responsible for giving the stack owner repo permissions to modify the stacks they own</li></ul> |


## Maintenance
During the course of its lifecycle, a stack or sample may need to be updated by the `Stack Provider`.  Types of updates can include:

* Changing the devfile content itself where components, commands, resources are modified
* Using a more secure container image(s)
* Implementing a new devfile spec version of the existing devfile e.g. multiple versions of devfiles exist for the same runtime supporting different versions of devtools.
* Implementing new additional devfile to the current stack or sample e.g. two devfiles, devfile.yaml and prod.devfile.yaml, exist for the same runtime supporting both inner and outer loop scenarios.
* Implementing a variation of an existing devfile using a different runtime version e.g. Devfile support for both  NodeJS v16 and v18


| Role             | Responsibilities                                                                                                                                                                                                                              |
|:-----------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Stack Provider` | <ul><li>Ensure stacks and samples are kept up to date by monitoring the health of their code and container images</li><li>Follow the [Update](https://github.com/devfile/registry/blob/main/CONTRIBUTING.md#updating) instructions </li></ul> |
| `Devfile Team`   | <ul><li>Conduct reviews of devfiles in the registries to ensure updates are happening on a regular basis</li><li>Communicate to `Stack Providers` any actions that need to be taken</li></ul>                                                 |
| `End User`       | <ul>[Report any issues](https://github.com/devfile/registry#reporting-any-issue) with the stacks and samples</ul>                                                                                                                             |


## Deprecation

When a stack or sample is no longer maintained due to inactivity, lack of timely updates, dependency on end-of-life (EOL) base images, etc it will be marked deprecated. The `Devfile Team` will reach out to the `Stack Provider` and get agreement before proceeding, but if there is no response within a 3-month timeframe, the  `Devfile Team` will take action and mark the devfile deprecated.

* Deprecated devfiles will remain in the community registry for 1 year before it’s removed.


| Role              | Responsibilities                                                                                                                                                                            |
|:------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Devfile Team`    | <ul><li>Communicate with the `Stack Providers` to advise them of the impending deprecation notice if devfile is deemed inactive </li> <li>Label the stack or sample as deprecated</li></ul> |
| `Stack Provider`  | <ul>Communicate with the `Devfile Team` and agree to have the deprecation notice set up</ul>                                                                                                  |
| `End User`| <ul>Take note of the deprecation notice and do not use the devfile for production</ul>                                                                                                                                                                                   |

### Ownership Transfers

When a stack provider is no longer able to maintain their stacks, an ownership transfer should take place. The stack provider is responsible to find their replacement. As it is described in the deprecation rules, if a stack is inactive for a long time - because of a failed ownership transfer - it will be marked deprecated.