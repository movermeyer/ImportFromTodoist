# `import_from_todoist`

<!-- Generated with "Markdown T​O​C" extension for Visual Studio Code -->
<!-- TOC -->

- [`import_from_todoist`](#import_from_todoist)
    - [Introduction](#introduction)
    - [WARNING: Unmaintained Repo!](#warning-unmaintained-repo)
    - [Quick Start](#quick-start)
        - [Pre-requisites](#pre-requisites)
        - [Usage](#usage)
            - [Example](#example)
            - [Caching](#caching)
    - [Data Model Overview](#data-model-overview)
            - [Top Level Objects](#top-level-objects)
            - [Tasks](#tasks)
            - [Projects](#projects)
    - [Nice Features](#nice-features)
    - [Not Implemented](#not-implemented)
        - [Missing Functionality](#missing-functionality)
        - [Other Aspects](#other-aspects)
    - [Contributing](#contributing)
        - [License](#license)

<!-- /TOC -->

## Introduction

This project allows you to import tasks from [Todoist](https://todoist.com/) into [GitHub Issues](https://guides.github.com/features/issues/).

This was originally written as a [take-home coding assignment](docs/problem_statement.md) for a position at GitHub. If you're looking at this from that perspective, you might be interested in the [design choices](docs/design_decisions.md), or a [code walkthrough](docs/code_walkthrough.md).

Coincidentally, this was also my very first Ruby code, so please excuse me if things are looking a little Pythonic :wink:
This project was originally written over the course of 1.5 weeks of part-time work.

## WARNING: Unmaintained Repo!

While I might further extend/polish this code in the future, as it stands currently I have no intentions of maintaining it. 
Consider this repo to be unmaintained, beta quality code.

## Quick Start

### Pre-requisites

* [Ruby](https://www.ruby-lang.org/en/) (Tested with [2.4.4](.ruby_version))
* [Git](https://git-scm.com/) (any modern version)
* [Bundler](https://bundler.io/)

1. Clone this repo using git: 
    ```
    git clone https://github.com/movermeyer/ImportFromTodoist ImportFromTodoist
    ```
1. Enter the directory that was created: 
    ```
    cd ImportFromTodoist
    ```
1. Fetch the Ruby dependencies:
    ```
    bundler install
    ```
1. Create a file called `.todoist_api_token` and put your [Todoist Personal API Token](https://todoist.com/Users/viewPrefs?page=integrations) into it.
    * Example: `0123456789abcdef0123456789abcdef01234567`
1. [Create a new GitHub Personal Access Token](https://github.com/settings/tokens/new)
    * To import into **private** repos: The token needs to have the `repo` permission
    * To import into **public** repos: The token only needs to have the `public_repo` permission
    * **Note:** Make sure to copy the generated token when it is shown to you. Otherwise, you'll have to delete the token and try again.
1. Create a file called `.github_auth_token` and put your [GitHub Personal Access Token](https://github.com/settings/tokens) into it.
    * Example: `058b8f7731bec63e2c68424e1f954c709615b981`
1. Create a new repo on GitHub to import into.
    * **Do not re-use an existing repo** unless you are very sure that is what you want.  

### Usage

Using `import_from_todoist` is done by calling the `cli.rb` script:

```
> ruby .\cli.rb --help
Import Todoist Tasks into GitHub Issues.
Usage: ./cli.rb [options]
        --projects x,y,z             Which Todoist projects to import tasks from.
        --repo user/repo             Which GitHub repo to import tasks into (ex. movermeyer/TestRepo).
        --no-cache                   Delete any caches prior to running
    -h, --help                       Prints this help
```

#### Example

```
ruby .\cli.rb --projects 'Goals,Calendar,Activities' --repo 'movermeyer/TestRepo'
```

This will sync the contents of the "Goals", "Calendar", "Activities" projects from Todoist into the `movermeyer/TestRepo` GitHub Repo (assuming all the projects and the repo exist).
Running it multiple times will only sync any changes made to the projects since the last execution.

**Note:** Access to the Todoist API is entirely **read-only**. This means that `import_from_todoist` will never make changes to your Todoist data. 

#### Caching

As part of carrying out its tasks, `import_from_todoist` produces caches of the objects from Todoist. The cache files are stored in `./.todoist_cache`.
To clear this cache, either delete the `./.todoist_cache` folder, or run `cli.rb` with the `--no-cache` option.

## Data Model Overview

`import_from_todoist` imports Todoist objects into GitHub.

Here is the high-level description of the conversion. For a detailed description of the mapping, as well as explanations of the reasoning behind it, see [Data Mapping](docs/data_mapping.md)

#### Top Level Objects

| Todoist Object  | GitHub Object |
| --------------- | ------------- |
| Task            | Issue         |
| Project         | Project       |

#### Tasks

| Todoist Object  | Result in GitHub                        |
| --------------- | --------------------------------------- |
| Task Due Date   | Milestone                               |
| Task Comment    | Comment on Issue                        |
| Task Label      | Label on Issue                          |
| Task Priority   | Label on Issue                          |
| Task Project    | Card in "To Do" column of Project       |
| Completed Task  | Issue closed                            |
| Assignee        | ❌ [Not implemented](#not-implemented) |
| Recurring Tasks | ❌ [Not implemented](#not-implemented) |
| Sub-tasks       | ❌ [Not implemented](#not-implemented) |
| Task Reminders  | ❌ [Not implemented](#not-implemented) |
| Favorite Tasks  | ❌ [Not implemented](#not-implemented) |

#### Projects

| Todoist Object    | Result in GitHub                        |
| ----------------- | --------------------------------------- |
| Project Comment   | Card in "Comments" Column               |
| Project archived  | Project closed                          |
| Sub-projects      | ❌ [Not implemented](#not-implemented) |
| Favorite Projects | ❌ [Not implemented](#not-implemented) |

## Nice Features

* **Idempotent:** 
  * You can run `cli.rb` as many times as you like, it will only make the changes necessary to bring GitHub into sync.
  * For example, this means that it will not produce duplicate issues if run multiple times.
  * In case of a network error, power outage, or similar failure, it's safe to simply run `cli.rb` again.
  * You may have to use the `--no-cache` flag in order for it to notice new changes. See [Caching](#caching) for details.

## Not Implemented

Due to the time constraints of the project, a number of features were not implemented:

### Missing Functionality
* Assignment of Tasks/Issues to collaborators (See [#9](https://github.com/movermeyer/ImportFromTodoist/issues/9))
* Attachments on Comments (See [#4](https://github.com/movermeyer/ImportFromTodoist/issues/4))
* Reactions on Comments (See [#5](https://github.com/movermeyer/ImportFromTodoist/issues/5))
* Issue ordering (within Projects) (See [#14](https://github.com/movermeyer/ImportFromTodoist/issues/14))
* Comment ordering (in Projects and Issues) (See [#3](https://github.com/movermeyer/ImportFromTodoist/issues/3))
* Deletion synchronization (See [#8](https://github.com/movermeyer/ImportFromTodoist/issues/8))
* Recurring Tasks (No native support in GitHub Issues)
* Task Reminders (No native support in GitHub Issues)

### Other Aspects

* Rate Limiting (See [#15](https://github.com/movermeyer/ImportFromTodoist/issues/15))
* Scaling to arbirarily large imports (See [#16](https://github.com/movermeyer/ImportFromTodoist/issues/16))
* Internationalization (i18n) (See [#18](https://github.com/movermeyer/ImportFromTodoist/issues/18))
* Project Auto-Kanban

## Contributing

As [mentioned above](#warning-unmaintained-repo), this project should be considered unmaintained.
However, contributions can still be made, and are still welcome.  :thumbsup: :smile: :thumbsup:

See [CONTRIBUTING.md](CONTRIBUTING.md) for discussions of how to contribute.

I will try my best to find the time to review and merge changes, but do not expect any active development outside of that.

### License
Feel free to take a look at, or play around with, the code (it's [ :sparkles: GPL licensed :sparkles:](LICENSE)).