# `import_from_todoist`

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

* [Ruby](https://www.ruby-lang.org/en/) (Tested with 2.4.4)
* [Git](https://git-scm.com/) (any modern version)
* [Bundler](https://bundler.io/)
    ```
    gem install bundler
    ```

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
    bundler
    ```
1. Create a file called `.todoist_api_token` and put your [Todoist Personal API Token](https://todoist.com/Users/viewPrefs?page=integrations) into it.
   * Example: `0123456789abcdef0123456789abcdef01234567`
1. [Create a new GitHub Personal Access Token](https://github.com/settings/tokens/new)
   * It needs to have the `public_repo` permission to be able to create Issues on public repos
   * TODO: What about private repos?
   * **Note:** Make sure to copy the generated token when it is shown to you. Otherwise, you'll have to delete the token and try again.
1. Create a file called `.github_auth_token` and put your [GitHub Personal Access Token](https://github.com/settings/tokens) into it.
   * Example: `058b8f7731bec63e2c68424e1f954c709615b981`

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
ruby .\cli.rb --projects 'GitHub Test 1,GitHub Test 2,GitHub Test 3' --repo 'movermeyer/TestRepo'
```

#### Caching

As part of carrying out its tasks, `import_from_todoist` produces caches of the objects from Todoist. The cache files are stored in `./.todoist_cache`.
To clear this cache, either delete the `./.todoist_cache` folder, or run `cli.rb` with the `--no-cache` option.

## Data Model Overview

`import_from_todoist` imports Todoist objects into GitHub.

Here is the high-level description of the conversion. For a detailed description of the mapping, as well as explanations of the reasoning behind it, see [TODO: Data Mapping page]. 

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

### Functionality
* Assignment of Tasks/Issues to collaborators
* Attachments on Comments
* Reactions on Comments
* Recurring Tasks
* Task Reminders
* Issue ordering (in Projects and Milestones)
* Comment ordering (in Projects and Issues)
* [Deletion synchronization](TODO: Make link to more discussion)

### Other Aspects

* [Rate Limiting](TODO: Make link to more discussion) 
* [Infinite scaling](TODO: Make link to more discussion)
* Internationalization (i18n)
* Project Auto-Kanban

## Advanced Usage

For a more in-depth discussion of each feature, see [TODO: Link to more discussion]

## Contributing

As mentioned in [TODO: Link], this project should be considered unmaintained.
However, contributions can still be made, and are still welcome  :thumbsup: :smile: :thumbsup:

See [CONTRIBUTING.md](CONTRIBUTING.md) for discussions of how to contribute.

### License
Feel free to take a look at, or play around with, the code (it's [ :sparkles: GPL licensed :sparkles:](LICENSE)).